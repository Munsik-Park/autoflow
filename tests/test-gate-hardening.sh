#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/hooks/check-autoflow-gate.sh docs/gate-matching-standard.md
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
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

# run_hook_out <expected_exit> <desc> <project_dir> <json> -- like run_hook but
# CAPTURES stderr for content assertions (issue #97 AC-hook-advisory-check:
# the standing ledger check emits a WARNING line the base run_hook discards).
# Sets HOOK_ERR as a side channel for a follow-up grep assertion.
run_hook_out() {
  local expected="$1" desc="$2" pdir="$3" json="$4" actual
  HOOK_ERR=$(printf '%s' "$json" | CLAUDE_PROJECT_DIR="$pdir" bash "$HOOK" 2>&1 >/dev/null)
  actual=$?
  if [[ "$actual" == "$expected" ]]; then
    echo "  PASS: $desc (exit $actual)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected exit $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

bash_json() { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(printf '%s' "$1" | jq -Rs .)"; }
# bash_bg_json — issue #134 background-deny payload surface: carries the
# PreToolUse run_in_background field alongside the command string.
bash_bg_json() { printf '{"tool_name":"Bash","tool_input":{"command":%s,"run_in_background":%s}}' "$(printf '%s' "$1" | jq -Rs .)" "$2"; }
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

echo "Issue #13 (T1) — AC-2k: label-gate no-over-block, cross-segment unrelated pair allowed"
# Segment-scoped label-gate condition B: the label path and -X DELETE must
# co-occur in ONE segment. Here the label path is in segment 1 (GET, no
# -X DELETE) and -X DELETE is in segment 2 (unrelated URL) — neither segment
# alone satisfies the AND, so this must allow (EXIT 0) once T1 lands.
# Currently EXIT 2 (whole-buffer AND) → RED.
run_hook 0 "AC-2k: ';'-separated unrelated pair (label GET ; unrelated DELETE) allowed" \
  "$NOSTATE" "$(bash_json 'gh api repos/o/r/issues/9/labels/blocked-by-review ; curl -X DELETE https://example.com/unrelated')"
run_hook 0 "AC-2k: '&&'-separated unrelated pair (label GET && unrelated DELETE) allowed" \
  "$NOSTATE" "$(bash_json 'gh api repos/o/r/issues/9/labels/blocked-by-review && curl -X DELETE https://example.com/unrelated')"

echo "Issue #13 (T2 / DCR-2 A) — AC-2l: P2 default-branch deny, git -c interposition base case"
run_hook 2 "AC-2l: 'git -c k=v push origin main' denied (interposed -c must not bypass)" \
  "$NOSTATE" "$(bash_json 'git -c k=v push origin main')"

echo "Issue #13 — AC-2m: P2 interposition option-variant matrix (all denied)"
run_hook 2 "AC-2m: 'git -C /path push origin main' denied" \
  "$NOSTATE" "$(bash_json 'git -C /path push origin main')"
run_hook 2 "AC-2m: 'git -c a=b -c c=d push origin main' denied (repeated -c)" \
  "$NOSTATE" "$(bash_json 'git -c a=b -c c=d push origin main')"
run_hook 2 "AC-2m: 'git -c k=v push origin HEAD:main' denied (alt refspec)" \
  "$NOSTATE" "$(bash_json 'git -c k=v push origin HEAD:main')"
run_hook 2 "AC-2m: 'git -c k=v push origin :main' denied (alt refspec)" \
  "$NOSTATE" "$(bash_json 'git -c k=v push origin :main')"

echo "Issue #13 — AC-2n: interposition over-block guard (must stay allowed; not a RED arm)"
run_hook 0 "AC-2n: 'git -c k=v commit -m x' allowed (not a push at all)" \
  "$NOSTATE" "$(bash_json 'git -c k=v commit -m x')"
run_hook 0 "AC-2n: 'git -c k=v push origin dev/x' allowed (non-default target, no active gate)" \
  "$NOSTATE" "$(bash_json 'git -c k=v push origin dev/x')"

echo "Issue #13 — AC-2o: Gate 3 score-gate witness under -c interposition"
run_hook 2 "AC-2o: active empty-scores 'git -c k=v push -u origin dev/x' blocked (Gate 3 fires)" \
  "$ACTIVE" "$(bash_json 'git -c k=v push -u origin dev/x')"
run_hook 0 "AC-2o: passing scores 'git -c k=v push -u origin dev/x' allowed (no over-block)" \
  "$PASSING" "$(bash_json 'git -c k=v push -u origin dev/x')"

echo "Issue #13 — AC-2p: third site (is_score_gated_surface :197) fail-closed under interposition"
run_hook 2 "AC-2p (RED-minimum): malformed state 'git -c k=v push origin dev/x' blocked (:295 fail-closed fires)" \
  "$MALFORMED" "$(bash_json 'git -c k=v push origin dev/x')"
run_hook 2 "AC-2p (additive): two-concatenated-object state 'git -c k=v push origin dev/x' blocked (same :295 path)" \
  "$TWO_OBJ" "$(bash_json 'git -c k=v push origin dev/x')"

echo "Issue #13 — AC-2q (doc-grep partial): gate-matching-standard.md records label-gate segmentation + git -c interposition allowance"
# Automatable slice only — semantic correctness of the prose is a manual
# review item (.autoflow/issue-13-manual-scenarios.md), not asserted here.
GATE_DOC="$PROJECT_ROOT/docs/gate-matching-standard.md"
if grep -qiE 'blocked-by-(review|subrepo)' "$GATE_DOC" \
   && grep -qi 'segment' "$GATE_DOC" \
   && grep -qi 'interposition' "$GATE_DOC" \
   && grep -qE -- '-[cC]\b' "$GATE_DOC"; then
  echo "  PASS: AC-2q: doc records label-gate segmentation + git -c interposition allowance"
  PASS=$((PASS + 1))
else
  echo "  FAIL: AC-2q: doc-grep — gate-matching-standard.md is missing label-gate segmentation and/or git -c interposition record"
  FAIL=$((FAIL + 1))
fi

echo "Issue #13 (AUDIT regression) — AC-2r: backslash-newline continuation is a single logical"
echo "  command, not a segment boundary — _SEGMENTS splits on physical newlines, so a"
echo "  backslash-continued command currently escapes the same-segment AND checks"
# AC-2r-1: label-gate co-occurrence AND (blocked-by-review path + -X DELETE) must
# still fire when the two tokens are joined by a backslash-newline continuation
# (one logical shell command). Reproduces the reported bypass payload verbatim.
run_hook 2 "AC-2r: label-gate backslash-continuation bypass 'blocked-by-review \\<NL> -X DELETE' denied" \
  "$NOSTATE" "$(bash_json $'gh api repos/o/r/issues/9/labels/blocked-by-review \\\n  -X DELETE')"
# AC-2r-2: same defect surface on the P2 default-branch push deny — a
# backslash-continued 'git push \<NL> origin main' is one logical command.
run_hook 2 "AC-2r: P2 push-deny backslash-continuation 'git push \\<NL> origin main' denied" \
  "$NOSTATE" "$(bash_json $'git push \\\n origin main')"
# AC-2r-3 (over-block guard): a REAL newline-separated pair of independent
# commands — not a backslash continuation — must stay allowed. The label path
# has no -X DELETE in its own segment, and the -X DELETE belongs to an
# unrelated curl call on the next line; legitimate newline segmentation must
# not regress. Distinct from AC-2k ('; '/'&&'-separated) — this is a bare
# newline-separated pair.
run_hook 0 "AC-2r: over-block guard — real newline-separated unrelated pair allowed" \
  "$NOSTATE" "$(bash_json $'gh api repos/o/r/issues/9/labels/blocked-by-review\ncurl -X DELETE https://api.example.com/unrelated')"

echo "Issue #13 (AUDIT fix-loop cycle 2) — AC-2s: BSD sed N-command failure on a"
echo "  trailing-backslash LAST line of the SCAN buffer discards the pattern space,"
echo "  so _JOINED / _SEGMENTS go empty and the P2 unconditional-deny checks never fire"
echo "  (macOS/BSD sed only — GNU sed preserves the line on the same input)"
# AC-2s-1: the SCAN buffer's last (only) line ends in a single trailing
# backslash with nothing after it (no continuation content follows — this is
# the failure shape, distinct from AC-2r's mid-buffer backslash-newline
# continuation which has a following line to join). On BSD sed, `N` at EOF
# with no next line fails and the pattern space is discarded, so _JOINED
# becomes empty and the P2 default-branch push deny never fires.
run_hook 2 "AC-2s-1: trailing-backslash-at-EOF 'git push origin main\\' denied" \
  "$NOSTATE" "$(bash_json 'git push origin main\')"
# AC-2s-2: same EOF-trailing-backslash shape on the label-gate co-occurrence
# deny (blocked-by-review path + -X DELETE in one logical command).
run_hook 2 "AC-2s-2: trailing-backslash-at-EOF label-DELETE denied" \
  "$NOSTATE" "$(bash_json 'gh api repos/o/r/issues/9/labels/blocked-by-review -X DELETE\')"
# AC-2s-3 (over-block guard): an innocuous command that happens to end in a
# trailing backslash must stay allowed — the fold-failure fix must not turn
# every trailing-backslash command into a blanket deny.
run_hook 0 "AC-2s-3: over-block guard — trailing-backslash innocuous 'echo done\\' allowed" \
  "$NOSTATE" "$(bash_json 'echo done\')"

echo "Issue #13 (AUDIT fix-loop cycle 3, user-approved) — AC-2t: the AC-2s fold-sed fix"
echo "  joins a backslash-newline continuation, but the joined line can ITSELF end in a"
echo "  bare trailing backslash at EOF — re-triggering the same BSD sed N-at-EOF discard"
echo "  one loop iteration later. A single fold pass is not enough for a 2+ hop chain."
# AC-2t-1: 2-hop payload — 'git push ' + backslash-newline + 'origin main' + bare
# trailing backslash at EOF. After the first join, the resulting logical line
# itself ends in a trailing backslash with no following line, reproducing
# AC-2s's N-at-EOF discard *inside* the fold loop.
run_hook 2 "AC-2t-1: 2-hop fold-then-EOF-backslash 'git push \\<NL>origin main\\' denied" \
  "$NOSTATE" "$(bash_json $'git push \\\norigin main\\')"
# AC-2t-2: same 2-hop shape on the label-gate co-occurrence deny.
run_hook 2 "AC-2t-2: 2-hop fold-then-EOF-backslash label-DELETE denied" \
  "$NOSTATE" "$(bash_json $'gh api repos/o/r/issues/9/labels/blocked-by-review \\\n  -X DELETE\\')"
# AC-2t-3: 3-hop variant (two intermediate continuations before the final
# bare-EOF backslash) — current (pre-fix) measured exit is 0 (bypass); this
# arm asserts the fix must generalize past a single re-trigger, not just 2-hop.
run_hook 2 "AC-2t-3: 3-hop fold-then-EOF-backslash 'git push \\<NL>-u \\<NL>origin main\\' denied" \
  "$NOSTATE" "$(bash_json $'git push \\\n-u \\\norigin main\\')"
# AC-2t-4 (over-block guard): an innocuous 2-hop backslash-continued command
# must stay allowed — the multi-hop fix must not turn every continuation
# chain into a blanket deny.
run_hook 0 "AC-2t-4: over-block guard — innocuous 2-hop 'echo a \\<NL>b\\' allowed" \
  "$NOSTATE" "$(bash_json $'echo a \\\nb\\')"

echo "Issue #13 (AUDIT fix-loop cycle 4, user-approved) — AC-2u: CR normalization"
echo "  before the backslash-newline fold. The AC-2t fold loop only strips a bare"
echo "  trailing backslash before LF; a CRLF-style continuation ('\\' + CR + LF)"
echo "  leaves a trailing CR on the joined line that is not the literal backslash"
echo "  the fold regex expects, so the join does not happen and the continuation"
echo "  passes through unmerged — the same class of bypass as AC-2t but via a"
echo "  CRLF line ending instead of a bare-EOF re-trigger."
# AC-2u-1: single-hop CRLF continuation on the P2 default-branch push deny —
# 'git push ' + backslash + CR + LF + 'origin main'. Current (pre-fix)
# measured exit is 0 (bypass); fix must normalize CR before folding.
run_hook 2 "AC-2u-1: CRLF-continuation 'git push \\<CR><NL>origin main' denied" \
  "$NOSTATE" "$(bash_json $'git push \\\r\norigin main')"
# AC-2u-2: same CRLF-continuation shape on the label-gate co-occurrence deny.
# Current (pre-fix) measured exit is 0 (bypass).
run_hook 2 "AC-2u-2: CRLF-continuation label-DELETE 'blocked-by-review \\<CR><NL>  -X DELETE' denied" \
  "$NOSTATE" "$(bash_json $'gh api repos/o/r/issues/9/labels/blocked-by-review \\\r\n  -X DELETE')"
# AC-2u-3 (over-block guard): a REAL CRLF-newline-separated pair of genuinely
# independent commands — no backslash continuation at all — must stay
# allowed. Distinct from AC-2r-3 (bare-LF, label-path content): this uses a
# CRLF line ending with unrelated echo commands, to confirm CR normalization
# does not turn every CRLF-terminated line into a folded/blocked one.
run_hook 0 "AC-2u-3: over-block guard — CRLF-separated unrelated pair 'echo x<CR><NL>echo y' allowed" \
  "$NOSTATE" "$(bash_json $'echo x\r\necho y')"

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
# Team-spawn form (POST-MIGRATION, issue #74 / ADR-0021): the teammate
# name-prefix channel is retired. ANY payload still carrying `.tool_input.name`
# resolves to "" (undeclared) and is denied, regardless of the prefix's
# apparent validity and regardless of any subagent_type riding along —
# resolving by subagent_type instead would silently admit an obsolete
# team-spawn attempt as a direct spawn and hide the caller's mistake.
run_hook 2 "team spawn name=impl-librechat → denied (name channel retired, undeclared)" \
  "$ACTIVE" "$(team_json 'impl-librechat' 'satisfy the acceptance criteria')"
run_hook 2 "team spawn name=test-librechat → denied (name channel retired, undeclared)" \
  "$ACTIVE" "$(team_json 'test-librechat' 'author the acceptance checks')"
run_hook 2 "team spawn name=eval-quality → denied (name channel retired, undeclared — no evaluation exemption via name)" \
  "$ACTIVE" "$(team_json 'eval-quality' 'score the completion rubric')"
run_hook 2 "team spawn undeclared name → denied" \
  "$ACTIVE" "$(team_json 'librechat-helper' 'assist with the task')"
# Mixed payload (PR #506 review, Medium — pre-migration; post-migration the
# same shape is governed by the name-presence deny above): a research/autoflow-*
# subagent_type riding along a `name` field does not rescue the payload —
# presence of `name` alone denies it, so subagent_type is never consulted.
run_hook 2 "mixed: subagent_type=Explore + name=impl-librechat → denied (name present, subagent_type not consulted)" \
  "$ACTIVE" "$(team_json_subtype 'impl-librechat' 'Explore' 'satisfy the acceptance criteria')"
run_hook 2 "mixed: subagent_type=Explore + name=test-librechat → denied (name present, subagent_type not consulted)" \
  "$ACTIVE" "$(team_json_subtype 'test-librechat' 'Explore' 'author the acceptance checks')"
run_hook 2 "mixed: subagent_type=autoflow-evaluator + name=impl-x → denied (name present, subagent_type not consulted)" \
  "$ACTIVE" "$(team_json_subtype 'impl-x' 'autoflow-evaluator' 'satisfy the acceptance criteria')"
run_hook 2 "mixed: subagent_type=Explore + undeclared name → denied (name present, subagent_type not consulted)" \
  "$ACTIVE" "$(team_json_subtype 'librechat-helper' 'Explore' 'assist with the task')"
run_hook 2 "mixed: subagent_type=Explore + name=eval-quality → denied (name channel retired, no evaluation exemption via name)" \
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

echo "Issue #97 — AC-hook-advisory-check: standing ledger check is non-gating (warn, never deny)"
# Feature design > standing-advisory-check: a non-gating step reads every live
# .autoflow/issue-*-ledger.md whose content differs from what it last
# observed, runs `scripts/ledger/ledger-entry-id.sh check` over it, and emits
# the defect lines as a WARNING -- it never converts a ledger defect into a
# denied tool call. Each fixture below is a FRESH project dir (its own mktemp)
# so no cross-test content-hash cache state leaks between assertions.
LEDGER_CHANGED_DEFECT=$(mktemp -d)   # fresh dir, ledger carries a duplicate O1
mkdir -p "$LEDGER_CHANGED_DEFECT/.autoflow"
cat > "$LEDGER_CHANGED_DEFECT/.autoflow/issue-9-ledger.md" <<'EOF'
# Decision Ledger — issue #9

## O1 — first decision (cycle 1, GATE:PLAN)

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, GATE:PLAN

## O1 — collided identifier, different title (cycle 1, VERIFY)

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, VERIFY
EOF

LEDGER_CHANGED_CLEAN=$(mktemp -d)    # fresh dir, ledger has no defects
mkdir -p "$LEDGER_CHANGED_CLEAN/.autoflow"
cat > "$LEDGER_CHANGED_CLEAN/.autoflow/issue-9-ledger.md" <<'EOF'
# Decision Ledger — issue #9

## O1 — first decision (cycle 1, GATE:PLAN)

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, GATE:PLAN
EOF

LEDGER_NO_SCRIPT=$(mktemp -d)        # fresh dir, defective ledger, but this
mkdir -p "$LEDGER_NO_SCRIPT/.autoflow"   # fixture's own scripts/ledger/ is absent
cat > "$LEDGER_NO_SCRIPT/.autoflow/issue-9-ledger.md" <<'EOF'
# Decision Ledger — issue #9

## O1 — dup (cycle 1, GATE:PLAN)

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, GATE:PLAN

## O1 — dup again (cycle 1, VERIFY)

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, VERIFY
EOF

run_hook_out 0 "changed ledger with a duplicate id -> tool call still ALLOWED (advisory, never denies)" \
  "$LEDGER_CHANGED_DEFECT" "$(bash_json 'git status')"
if printf '%s' "$HOOK_ERR" | grep -qE 'O1'; then
  echo "  PASS: warning stderr names the colliding identifier (O1)"
  PASS=$((PASS + 1))
else
  echo "  FAIL: warning stderr does not name the colliding identifier (O1) -- got: $HOOK_ERR"
  FAIL=$((FAIL + 1))
fi

echo "Issue #97 — AC-hook-advisory-check: content-hash cache suppresses a REPEAT warning on an unchanged ledger"
# Same fixture dir as the assertion above, called a SECOND time with the
# ledger file byte-identical to the first call — the step's content-hash
# cache (feature design > standing-advisory-check > Cache location) must
# recognize "unchanged since last observed" and stay silent, so a defective
# ledger does not repeat the same warning on every tool call of a session.
run_hook_out 0 "second call, SAME unchanged defective ledger -> allowed" \
  "$LEDGER_CHANGED_DEFECT" "$(bash_json 'git status')"
if printf '%s' "$HOOK_ERR" | grep -qE 'O1'; then
  echo "  FAIL: second call on an unchanged ledger repeated the warning (cache did not suppress it) -- got: $HOOK_ERR"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: second call on an unchanged ledger is silent (cache-hit suppression)"
  PASS=$((PASS + 1))
fi

echo "Issue #97 — AC-hook-advisory-check: content-hash cache suppresses a REPEAT warning under a WHITESPACE project path"
# Same shape as the cache-hit suppression case above, but the fixture project
# dir itself contains a space (e.g. an "af space" subdir under mktemp -d).
# Reviewer finding (PR #104, Low): the cache row lookup uses awk's default
# whitespace field splitting ($2 == p), so a stored path containing a space
# never matches on the second call -- the cache never hits, and an unchanged
# defective ledger re-warns on every call instead of being suppressed.
LEDGER_WS_PARENT=$(mktemp -d)
LEDGER_WS_DEFECT="$LEDGER_WS_PARENT/af space"
mkdir -p "$LEDGER_WS_DEFECT/.autoflow"
cat > "$LEDGER_WS_DEFECT/.autoflow/issue-9-ledger.md" <<'EOF'
# Decision Ledger — issue #9

## O1 — first decision (cycle 1, GATE:PLAN)

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, GATE:PLAN

## O1 — collided identifier, different title (cycle 1, VERIFY)

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, VERIFY
EOF

run_hook_out 0 "whitespace-path fixture, first call, defective ledger -> allowed" \
  "$LEDGER_WS_DEFECT" "$(bash_json 'git status')"

run_hook_out 0 "whitespace-path fixture, second call, SAME unchanged defective ledger -> allowed" \
  "$LEDGER_WS_DEFECT" "$(bash_json 'git status')"
if printf '%s' "$HOOK_ERR" | grep -qE 'O1'; then
  echo "  FAIL: second call on an unchanged ledger under a whitespace project path repeated the warning (cache did not suppress it) -- got: $HOOK_ERR"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: second call on an unchanged ledger under a whitespace project path is silent (cache-hit suppression)"
  PASS=$((PASS + 1))
fi

run_hook_out 0 "changed CLEAN ledger -> allowed and silent (no false-positive warning)" \
  "$LEDGER_CHANGED_CLEAN" "$(bash_json 'git status')"
if [ -z "$HOOK_ERR" ] || ! printf '%s' "$HOOK_ERR" | grep -qiE 'duplicate-id|unidentified-entry'; then
  echo "  PASS: no defect line for a clean ledger"
  PASS=$((PASS + 1))
else
  echo "  FAIL: clean ledger produced a defect line -- got: $HOOK_ERR"
  FAIL=$((FAIL + 1))
fi

echo "Issue #97 — AC-hook-advisory-check: absent-script tolerance (silent no-op)"
run_hook 0 "defective ledger + missing scripts/ledger/ledger-entry-id.sh helper -> allowed, no crash" \
  "$LEDGER_NO_SCRIPT" "$(bash_json 'git status')"

echo "Issue #97 — AC-hook-advisory-check: a gated command denied on its OWN gate is denied for its own reason, never for a ledger defect"
ACTIVE_LEDGER_DEFECT=$(mktemp -d)
mkdir -p "$ACTIVE_LEDGER_DEFECT/.autoflow"
cat > "$ACTIVE_LEDGER_DEFECT/.autoflow/issue-9.json" <<'EOF'
{ "active": true, "issue": "#9",
  "phases": { "audit": {"scores":{}}, "gate_quality": {"scores":{}} } }
EOF
cat > "$ACTIVE_LEDGER_DEFECT/.autoflow/issue-9-ledger.md" <<'EOF'
# Decision Ledger — issue #9

## O1 — dup (cycle 1, GATE:PLAN)

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, GATE:PLAN

## O1 — dup again (cycle 1, VERIFY)

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, VERIFY
EOF
run_hook_out 2 "empty-scores active state + git push -> still denied for the score-gate reason (2)" \
  "$ACTIVE_LEDGER_DEFECT" "$(bash_json 'git push -u origin dev/x')"
if printf '%s' "$HOOK_ERR" | grep -qiE 'BLOCKED'; then
  echo "  PASS: denial reason is the score gate's own BLOCKED message, not a ledger-only rejection"
  PASS=$((PASS + 1))
else
  echo "  FAIL: expected the score gate's own BLOCKED reason in stderr -- got: $HOOK_ERR"
  FAIL=$((FAIL + 1))
fi

echo "Issue #97 — AC-hook-advisory-check: reachability clause -- the step still fires on all three exit-0-before-end paths"
# The placement [MUST] (feature design > standing-advisory-check) requires the
# step to sit BEFORE Section 2's activity check, so it must still run (and
# still warn on a defective ledger) under every condition the script exits 0
# early: no state file, state present but active != true, and a research/
# analysis/evaluation Agent spawn. A step placed AFTER any one of these would
# pass the two cases above and silently never run for this traffic.
LEDGER_NOSTATE=$(mktemp -d)
mkdir -p "$LEDGER_NOSTATE/.autoflow"
cp "$LEDGER_CHANGED_DEFECT/.autoflow/issue-9-ledger.md" "$LEDGER_NOSTATE/.autoflow/issue-9-ledger.md"
run_hook_out 0 "reachability: NO state file + Bash call + defective ledger -> still warns" \
  "$LEDGER_NOSTATE" "$(bash_json 'git status')"
if printf '%s' "$HOOK_ERR" | grep -qE 'O1'; then
  echo "  PASS: defect line present with no state file"
  PASS=$((PASS + 1))
else
  echo "  FAIL: no defect line with no state file -- got: $HOOK_ERR"
  FAIL=$((FAIL + 1))
fi

LEDGER_INACTIVE=$(mktemp -d)
mkdir -p "$LEDGER_INACTIVE/.autoflow"
cp "$LEDGER_CHANGED_DEFECT/.autoflow/issue-9-ledger.md" "$LEDGER_INACTIVE/.autoflow/issue-9-ledger.md"
cat > "$LEDGER_INACTIVE/.autoflow/issue-9.json" <<'EOF'
{ "active": false, "issue": "#9", "phases": {} }
EOF
run_hook_out 0 "reachability: state present but active:false + defective ledger -> still warns" \
  "$LEDGER_INACTIVE" "$(bash_json 'git status')"
if printf '%s' "$HOOK_ERR" | grep -qE 'O1'; then
  echo "  PASS: defect line present with active:false state"
  PASS=$((PASS + 1))
else
  echo "  FAIL: no defect line with active:false state -- got: $HOOK_ERR"
  FAIL=$((FAIL + 1))
fi

LEDGER_RESEARCH=$(mktemp -d)
mkdir -p "$LEDGER_RESEARCH/.autoflow"
cp "$LEDGER_CHANGED_DEFECT/.autoflow/issue-9-ledger.md" "$LEDGER_RESEARCH/.autoflow/issue-9-ledger.md"
run_hook_out 0 "reachability: research/analysis/evaluation Agent spawn + defective ledger -> still warns" \
  "$LEDGER_RESEARCH" "$(agent_json 'Explore' 'search the repository')"
if printf '%s' "$HOOK_ERR" | grep -qE 'O1'; then
  echo "  PASS: defect line present on a research-role Agent spawn"
  PASS=$((PASS + 1))
else
  echo "  FAIL: no defect line on a research-role Agent spawn -- got: $HOOK_ERR"
  FAIL=$((FAIL + 1))
fi

rm -rf "$LEDGER_CHANGED_DEFECT" "$LEDGER_CHANGED_CLEAN" "$LEDGER_NO_SCRIPT" "$ACTIVE_LEDGER_DEFECT" "$LEDGER_NOSTATE" "$LEDGER_INACTIVE" "$LEDGER_RESEARCH"

echo "Issue #134 — background-deny-fires: a backgrounded run-suites.sh invocation is refused at the tool boundary"
# feature design > background-deny: three surfaces (payload, prefix nohup/setsid,
# trailing-&) composed on the deny-local BG_SCAN buffer. All state-independent —
# run under $NOSTATE throughout (deny fires with no cycle in flight).
run_hook 2 "payload surface: run_in_background=true + run-suites.sh in command" \
  "$NOSTATE" "$(bash_bg_json 'bash scripts/test/run-suites.sh --all' 'true')"
run_hook 2 "prefix surface isolated: nohup, no trailing & (BG_TAIL alone would admit)" \
  "$NOSTATE" "$(bash_json 'nohup bash scripts/test/run-suites.sh --all')"
run_hook 2 "prefix surface, quoted path, isolated: nohup + quoted invocation, no trailing &" \
  "$NOSTATE" "$(bash_json 'nohup bash "$ROOT/scripts/test/run-suites.sh" --all')"
run_hook 2 "prefix surface, setsid counterpart" \
  "$NOSTATE" "$(bash_json 'setsid bash scripts/test/run-suites.sh --all')"
run_hook 2 "wrapper group isolated: env FOO=1 ... &  (no nohup/setsid to catch it)" \
  "$NOSTATE" "$(bash_json 'env FOO=1 bash scripts/test/run-suites.sh --all &')"
run_hook 2 "wrapper group isolated: time ... &" \
  "$NOSTATE" "$(bash_json 'time bash scripts/test/run-suites.sh --all &')"
run_hook 2 "argument-less trailing &: bash .../run-suites.sh& (no char for a mandatory-run class to consume)" \
  "$NOSTATE" "$(bash_json 'bash scripts/test/run-suites.sh&')"
run_hook 2 "quoting pair: fully double-quoted invocation path, trailing &" \
  "$NOSTATE" "$(bash_json 'bash "$ROOT/scripts/test/run-suites.sh" --all &')"
run_hook 2 "quoting pair: fully single-quoted absolute invocation path, trailing &" \
  "$NOSTATE" "$(bash_json "bash '/abs/scripts/test/run-suites.sh' --all &")"
run_hook 2 "quoting pair: nohup composition of the quoted-path form" \
  "$NOSTATE" "$(bash_json 'nohup bash "$ROOT/scripts/test/run-suites.sh" --all &')"
run_hook 2 "ordering leg: quoted-path run backgrounded, followed by an unrelated quoted arg carrying ';'" \
  "$NOSTATE" "$(bash_json 'bash "$ROOT/scripts/test/run-suites.sh" --all & echo "a; b"')"
run_hook 2 "no-state-file direction pinned: deny fires with NO state file present" \
  "$NOSTATE" "$(bash_json 'bash scripts/test/run-suites.sh --all &')"

echo "Issue #134 — background-deny-discriminates: backgrounding vs. shell tokens that merely resemble it; invocation vs. mention"
run_hook 0 "separator discrimination: cd x && run-suites.sh --all (foreground AND-list)" \
  "$NOSTATE" "$(bash_json 'cd x && bash scripts/test/run-suites.sh --all')"
run_hook 2 "separator discrimination: same command, trailing & backgrounds the whole AND-list" \
  "$NOSTATE" "$(bash_json 'cd x && bash scripts/test/run-suites.sh --all &')"
run_hook 0 "separator discrimination: leading & ends a PRIOR job, this invocation is foreground" \
  "$NOSTATE" "$(bash_json 'a & bash scripts/test/run-suites.sh --all')"
run_hook 2 "compound backgrounding: pipeline backgrounded as a whole (| tee log &)" \
  "$NOSTATE" "$(bash_json 'bash scripts/test/run-suites.sh --all | tee log &')"
run_hook 2 "compound backgrounding: AND-list backgrounded as a whole (&& echo done &)" \
  "$NOSTATE" "$(bash_json 'bash scripts/test/run-suites.sh --all && echo done &')"
run_hook 0 "compound backgrounding: ';' list backgrounds only its LAST command" \
  "$NOSTATE" "$(bash_json 'bash scripts/test/run-suites.sh --all; echo done &')"
run_hook 2 "compound backgrounding: file-descriptor redirect then trailing &" \
  "$NOSTATE" "$(bash_json 'bash scripts/test/run-suites.sh --all > log 2>&1 &')"
run_hook 0 "command-position discrimination: backgrounded grep merely MENTIONING the path" \
  "$NOSTATE" "$(bash_json 'grep run-suites.sh notes.txt &')"
run_hook 0 "command-position discrimination: backgrounded git add merely naming the path" \
  "$NOSTATE" "$(bash_json 'git add scripts/test/run-suites.sh && echo ok &')"
run_hook 2 "command-position discrimination: the real backgrounded invocation still denies" \
  "$NOSTATE" "$(bash_json 'bash scripts/test/run-suites.sh --all &')"

echo "Issue #134 — background-deny-does-not-over-block: no legitimate invocation is refused"
run_hook 0 "foreground --all admitted" \
  "$NOSTATE" "$(bash_json 'bash scripts/test/run-suites.sh --all')"
run_hook 0 "foreground --selected admitted" \
  "$NOSTATE" "$(bash_json 'bash scripts/test/run-suites.sh --selected .autoflow/issue-134-run-set.txt')"
run_hook 0 "redirection form containing & but not backgrounding: &> log" \
  "$NOSTATE" "$(bash_json 'bash scripts/test/run-suites.sh --all &> log')"
run_hook 0 "redirection form containing & but not backgrounding: > log 2>&1" \
  "$NOSTATE" "$(bash_json 'bash scripts/test/run-suites.sh --all > log 2>&1')"
run_hook 0 "unrelated command with the background field set is not this deny's concern" \
  "$NOSTATE" "$(bash_bg_json 'git status' 'true')"
run_hook 0 "path-token boundary: bash x/my-run-suites.sh --all & (different script, path group must require the trailing /)" \
  "$NOSTATE" "$(bash_json 'bash x/my-run-suites.sh --all &')"
run_hook 0 "quoted-mention admit: gh pr create body describing the deny (BG_TAIL anchor)" \
  "$NOSTATE" "$(bash_json 'gh pr create --body "run bash scripts/test/run-suites.sh --all" &')"
run_hook 0 "quoted-mention admit: git commit -m describing the deny (BG_TAIL anchor)" \
  "$NOSTATE" "$(bash_json 'git commit -m "ran bash scripts/test/run-suites.sh --all in bg" &')"
run_hook 0 "quoted-body-own-separator triple: prose body's own ';' does not manufacture a boundary (BG_TAIL arm)" \
  "$NOSTATE" "$(bash_json 'git commit -m "deny: run it; bash scripts/test/run-suites.sh --all & is refused"')"
run_hook 0 "quoted-body-own-separator triple: prose body's own '&&' does not manufacture a boundary (BG_TAIL arm)" \
  "$NOSTATE" "$(bash_json 'gh pr comment 1 --body "e.g. cd x && bash scripts/test/run-suites.sh --all & now denies"')"
run_hook 0 "quoted-body-own-separator triple: prose body's own ';' does not manufacture a boundary (BG_PREFIX arm)" \
  "$NOSTATE" "$(bash_json 'gh pr create --body "the deny fires; nohup bash scripts/test/run-suites.sh --all is refused"')"
run_hook 0 "no-state-file direction pinned: admits stay admitted with NO state file present" \
  "$NOSTATE" "$(bash_json 'bash scripts/test/run-suites.sh --all')"

echo "Issue #134 c2 — background-deny-fires: continuation fold / heredoc strip / post-heredoc tail (AC1, AC2, AC5, stage order, carried findings F1-F3)"
# feature design (cycle 2) > shared-fold / heredoc-strip / bg-pipeline. Buffer
# widens from a shell PHYSICAL line to a shell LOGICAL line (backslash-newline
# continuations folded) and heredoc bodies are deleted-and-continued instead of
# truncating the whole buffer at the first `<<`. All state-independent -- run
# under $NOSTATE throughout, as the cycle-1 legs above do.
run_hook 2 "AC1 continuation-fold: one-hop backslash-newline before &" \
  "$NOSTATE" "$(bash_json $'bash scripts/test/run-suites.sh --all \\\n&')"
run_hook 2 "AC1 continuation-fold: multi-hop continuation splits interpreter, path and &" \
  "$NOSTATE" "$(bash_json $'bash \\\nscripts/test/run-suites.sh \\\n--all \\\n&')"
run_hook 2 "AC1 continuation-fold: CRLF spelling of the one-hop form" \
  "$NOSTATE" "$(bash_json $'bash scripts/test/run-suites.sh --all \\\r\n&')"
run_hook 2 "AC1 continuation-fold: prefix surface -- nohup split from the invocation by a continuation" \
  "$NOSTATE" "$(bash_json $'nohup \\\nbash scripts/test/run-suites.sh --all')"
# carried finding F3: the discriminating payload-surface shape is
# run_in_background:true + an invocation placed AFTER a terminated heredoc --
# HEAD admits it (the cycle-1 `${COMMAND%%<<*}` truncation removes everything
# from the heredoc introducer onward, including the invocation). A
# continuation-split invocation with no `&` is NOT used here: grep -qE matches
# per PHYSICAL line, so the split invocation's own line already starts with
# the path token and RUN_SUITES already matches it at HEAD -- that shape does
# not discriminate cycle-1 from cycle-2 behavior.
run_hook 2 "payload surface (F3): run_in_background=true + invocation after a terminated heredoc" \
  "$NOSTATE" "$(bash_bg_json $'cat <<EOF > doc.md\ntext\nEOF\nbash scripts/test/run-suites.sh --all' 'true')"
run_hook 2 "AC2 heredoc-introducer: bare <<EOF & (introducer deleted, & retained)" \
  "$NOSTATE" "$(bash_json $'bash scripts/test/run-suites.sh --all <<EOF &\nbody\nEOF')"
run_hook 2 "AC2 heredoc-introducer: tab-stripping <<-EOF &" \
  "$NOSTATE" "$(bash_json $'bash scripts/test/run-suites.sh --all <<-EOF &\n\tbody\nEOF')"
run_hook 2 "AC2 heredoc-introducer: quoted-delimiter <<\"EOF\" &" \
  "$NOSTATE" "$(bash_json $'bash scripts/test/run-suites.sh --all <<"EOF" &\nbody\nEOF')"
run_hook 2 "stage-order-pinned: continuation precedes the heredoc introducer (fold before strip)" \
  "$NOSTATE" "$(bash_json $'bash scripts/test/run-suites.sh --all \\\n<<EOF &\nbody\nEOF')"
run_hook 2 "AC5 post-heredoc tail: bare heredoc block, invocation backgrounded on a LATER line" \
  "$NOSTATE" "$(bash_json $'cat <<EOF > doc.md\ntext\nEOF\nbash scripts/test/run-suites.sh --all &')"
run_hook 2 "AC5 post-heredoc tail: <<-EOF spelling, invocation backgrounded on a LATER line" \
  "$NOSTATE" "$(bash_json $'cat <<-EOF > doc.md\n\ttext\nEOF\nbash scripts/test/run-suites.sh --all &')"
run_hook 2 "AC5 post-heredoc tail: quoted-delimiter <<\"EOF\" spelling, invocation backgrounded on a LATER line" \
  "$NOSTATE" "$(bash_json $'cat <<"EOF" > doc.md\ntext\nEOF\nbash scripts/test/run-suites.sh --all &')"
run_hook 2 "AC5 post-here-string tail: an earlier here-string command, invocation backgrounded on a LATER line" \
  "$NOSTATE" "$(bash_json $'grep -q x <<< \"\$V\"\nbash scripts/test/run-suites.sh --all &')"
# misread-introducer-is-bounded -- deny half: a quoted `<<` mention on an
# earlier logical line opens a heredoc that never terminates; totality buffers
# (never discards) the body, so the following REAL invocation line survives
# and this denies. The admit half sits in -does-not-over-block below.
run_hook 2 "misread-introducer-is-bounded (deny half): a quoted << mention on an earlier line does not drop the following real invocation" \
  "$NOSTATE" "$(bash_json $'git commit -m \"note << here\"\nbash scripts/test/run-suites.sh --all &')"

echo "Issue #134 c2 — background-deny-discriminates: multi-line admits stay admitted (AC3)"
run_hook 0 "AC3 discrimination: bare newline separates a foreground invocation from a LATER backgrounded command" \
  "$NOSTATE" "$(bash_json $'bash scripts/test/run-suites.sh --all\necho done &')"
run_hook 0 "AC3 discrimination: a backgrounded unrelated command stands BEFORE the foreground invocation" \
  "$NOSTATE" "$(bash_json $'echo start &\nbash scripts/test/run-suites.sh --all')"
run_hook 0 "AC3 discrimination: a continuation that ends without & stays admitted" \
  "$NOSTATE" "$(bash_json $'bash scripts/test/run-suites.sh --selected \\\n.autoflow/issue-134-run-set.txt')"

echo "Issue #134 c2 — background-deny-does-not-over-block: heredoc-body mentions, continuation-spanning quotes, degenerate input (AC3, totality)"
run_hook 0 "AC3 quoted-body-still-admits: heredoc body merely WRITES the denied command text" \
  "$NOSTATE" "$(bash_json $'cat <<EOF > doc.md\nbash scripts/test/run-suites.sh --all &\nEOF')"
# the fold must run BEFORE the unquoting stage: if unquoting ran first, the
# quote parity across the continuation would already be broken by the time the
# fold joined the two physical lines, and this leg denies instead of admits.
run_hook 0 "AC3 quoted-body-still-admits: git commit -m quoted message spans a continuation and ends in &" \
  "$NOSTATE" "$(bash_json $'git commit -m \"deny fires when \\\nbash scripts/test/run-suites.sh --all &\"')"
run_hook 0 "misread-introducer-is-bounded (admit half): single-line quoted << mention of the denied command" \
  "$NOSTATE" "$(bash_json 'git commit -m "note << bash scripts/test/run-suites.sh --all &"')"
run_hook 0 "degenerate-input-totality: empty command" \
  "$NOSTATE" "$(bash_json '')"
run_hook 0 "degenerate-input-totality: command is a single bare newline" \
  "$NOSTATE" "$(bash_json $'\n')"

echo "Issue #134 c2 — joined-parity: _fold_continuations output is byte-exact against the documented fold contract (carried finding F1)"
# carried finding F1: a leg that MEASURES _JOINED byte-parity directly, not
# only "siblings stay green". _fold_continuations is sourced from the hook at
# GLOBAL SCOPE (feature design > shared-fold) in an isolated subshell: TOOL_NAME
# is set to a value matching neither "Bash" nor "Agent" so no side-effecting
# block runs, and `exit` is shadowed so the hook's own unconditional trailing
# `exit 0` (check-autoflow-gate.sh, last line) returns control to this probe
# instead of terminating it before the function call. The sentinel
# append/strip idiom (feature design > joined-parity's own call-site pattern)
# is reused here so a genuine trailing blank logical line is not silently
# stripped by command substitution before the comparison runs.
#
# RED2 (issue #134 c2, VERIFY cause branch, ledger O18): stdin was originally
# fed to `source` through a PIPE (`printf … | … source "$HOOK"`) -- `source`
# was the pipeline's LAST command, but the pipeline as a whole still ran in a
# separate subshell from `_fold_continuations`' later call site (measured
# under bash 5.3.9 and /bin/bash 3.2.57: `_fold_continuations` was undefined
# after the pipe form, defined after a plain `<<<` redirection). Fixed by
# feeding stdin via a HEREDOC/HERESTRING REDIRECTION on the `source` command
# itself, which attaches no extra subshell, keeping the isolated-subshell /
# shadowed-`exit` protections unchanged. `hook` is parameterized (default
# $HOOK) so the same probe can Red-confirm against a hook copy that lacks the
# function (see the Red-confirmation measurement below / the c2 RED2 report).
_probe_fold() {
  local probe="$1" hook="${2:-$HOOK}" out
  out=$(
    exit() { return 0; }
    CLAUDE_PROJECT_DIR="$NOSTATE" source "$hook" <<< '{"tool_name":"Noop","tool_input":{}}' >/dev/null 2>&1
    _fold_continuations <<< "$probe"
    printf X
  )
  printf '%s' "${out%X}"
}
_assert_fold() {
  # The sentinel append/strip idiom is reapplied HERE too: $(_probe_fold ...)
  # is itself a command substitution and strips a trailing newline from
  # _probe_fold's own output, which would silently re-drop the very
  # trailing-blank-logical-line case this leg exists to catch (RED2, same
  # root cause as the sourcing fix above -- an outer capture undoing an
  # inner one).
  local desc="$1" probe="$2" expected="$3" got
  got=$(_probe_fold "$probe"; printf X); got="${got%X}"
  if [[ "$got" == "$expected" ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected $(printf '%q' "$expected"), got $(printf '%q' "$got"))"
    FAIL=$((FAIL + 1))
  fi
}
_assert_fold "empty input folds to empty" "" ""
_assert_fold "bare newline folds to a single newline" $'\n' $'\n'
_assert_fold "single-hop continuation joins with one space, backslash removed" $'a\\\nb' 'a b'
_assert_fold "multi-hop continuation joins every hop" $'a\\\nb\\\nc' 'a b c'
_assert_fold "continuation at EOF keeps content, backslash removed, no join" $'a\\' 'a'
_assert_fold "CRLF continuation is stripped before the continuation test, then joined" $'a\\\r\nb' 'a b'
_assert_fold "a genuine trailing blank logical line is preserved, not silently dropped" $'a\n' $'a\n'

echo "=============================="
echo "Results: $((PASS + FAIL)) total, $PASS passed, $FAIL failed"
echo "=============================="
[[ $FAIL -eq 0 ]]
