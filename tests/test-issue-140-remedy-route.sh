#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/gate/remedy-route.sh .claude/hooks/check-autoflow-gate.sh tests/fixtures/issue-140-ledger-138.md
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: late-gate FAIL cause-branch re-entry (issue #140)
# =============================================================================
# Three subjects, each asserted by execution:
#   1. scripts/gate/remedy-route.sh — the class → re-entry table, the
#      farthest-wins rule for mixed classes, `operator` pausing regardless of
#      its neighbours, and the default item → class table.
#   2. Replay on the #138 cycle-1 ledger excerpt (tests/fixtures/
#      issue-140-ledger-138.md): the three GATE:QUALITY FAILs O5 / O7 / O9 all
#      classify `doc`, route DOC_COMMIT, and no replayed route is RED.
#   3. Hook Gate 5 — `git commit` under a state whose latest GATE:QUALITY
#      record carries remedy_class "doc" is denied until the sweep record
#      .autoflow/issue-N-remedy-sweep.md exists with non-empty `## Command`
#      and `## Output` sections; a non-`doc` class, an absent class, and a
#      non-commit command stay ungated; `remedy_class` as a phase-object
#      sibling key is NOT a MALFORMED state (the closed-world validator is
#      top-level and score-shaped only).
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$PROJECT_ROOT/.claude/hooks/check-autoflow-gate.sh"
ROUTE="$PROJECT_ROOT/scripts/gate/remedy-route.sh"
FIXTURE="$PROJECT_ROOT/tests/fixtures/issue-140-ledger-138.md"

PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected '$expected', got '$actual')"; FAIL=$((FAIL + 1))
  fi
}

run_hook() {
  local expected="$1" desc="$2" pdir="$3" json="$4" actual
  actual=$(printf '%s' "$json" | CLAUDE_PROJECT_DIR="$pdir" bash "$HOOK" >/dev/null 2>&1; echo $?)
  assert_eq "$desc (exit)" "$expected" "$actual"
}

run_hook_stderr() {
  local expected="$1" reason_substr="$2" desc="$3" pdir="$4" json="$5" actual stderr_out
  stderr_out=$(mktemp)
  actual=$(printf '%s' "$json" | CLAUDE_PROJECT_DIR="$pdir" bash "$HOOK" >/dev/null 2>"$stderr_out"; echo $?)
  if [[ "$actual" == "$expected" ]] && grep -qF "$reason_substr" "$stderr_out"; then
    echo "  PASS: $desc (exit $actual, reason contains '$reason_substr')"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected exit $expected w/ '$reason_substr', got exit $actual: $(head -1 "$stderr_out"))"; FAIL=$((FAIL + 1))
  fi
  rm -f "$stderr_out"
}

bash_json() { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(printf '%s' "$1" | jq -Rs .)"; }

echo "=== 1. route table ==="
assert_eq "doc → DOC_COMMIT"           "DOC_COMMIT" "$(bash "$ROUTE" route doc)"
assert_eq "test → RED"                 "RED"        "$(bash "$ROUTE" route test)"
assert_eq "impl → GREEN"               "GREEN"      "$(bash "$ROUTE" route impl)"
assert_eq "design → ARCHITECT"         "ARCHITECT"  "$(bash "$ROUTE" route design)"
assert_eq "operator → PAUSE"           "PAUSE"      "$(bash "$ROUTE" route operator)"
assert_eq "mixed doc+test → RED (farthest wins)"        "RED"       "$(bash "$ROUTE" route doc test)"
assert_eq "mixed doc+test+impl → GREEN"                 "GREEN"     "$(bash "$ROUTE" route test doc impl)"
assert_eq "mixed design+doc → ARCHITECT"                "ARCHITECT" "$(bash "$ROUTE" route doc design)"
assert_eq "operator anywhere → PAUSE (design present)"  "PAUSE"     "$(bash "$ROUTE" route design operator)"
assert_eq "unknown class → exit 2" "2" "$(bash "$ROUTE" route nonsense >/dev/null 2>&1; echo $?)"
assert_eq "no class → exit 2"      "2" "$(bash "$ROUTE" route >/dev/null 2>&1; echo $?)"

echo "=== 1b. default item → class ==="
assert_eq "Doc updates → doc"            "doc"    "$(bash "$ROUTE" default-class 'Doc updates')"
assert_eq "Test coverage → test"         "test"   "$(bash "$ROUTE" default-class 'Test coverage')"
assert_eq "Test quality → test"          "test"   "$(bash "$ROUTE" default-class 'Test quality')"
assert_eq "Minimal implementation → impl" "impl"  "$(bash "$ROUTE" default-class 'Minimal implementation')"
assert_eq "Fit → design"                 "design" "$(bash "$ROUTE" default-class 'Fit')"
assert_eq "unknown item → exit 2" "2" "$(bash "$ROUTE" default-class 'Vibes' >/dev/null 2>&1; echo $?)"

echo "=== 2. replay on the #138 ledger excerpt ==="
REPLAY=$(bash "$ROUTE" replay "$FIXTURE")
assert_eq "replay exit 0" "0" "$(bash "$ROUTE" replay "$FIXTURE" >/dev/null 2>&1; echo $?)"
assert_eq "replay yields exactly the three FAIL entries" "3" "$(printf '%s\n' "$REPLAY" | grep -c .)"
for id in O5 O7 O9; do
  assert_eq "$id classifies doc → DOC_COMMIT" "$id	doc	DOC_COMMIT" "$(printf '%s\n' "$REPLAY" | grep "^$id	" || echo missing)"
done
assert_eq "O8 (VALIDATE/AUDIT PASS record) is not a FAIL entry" "0" "$(printf '%s\n' "$REPLAY" | grep -c '^O8')"
assert_eq "no replayed route is RED" "0" "$(printf '%s\n' "$REPLAY" | grep -c 'RED$')"
assert_eq "ledger without a GATE:QUALITY FAIL → exit 2" "2" "$(printf '## O1 — x (cycle 1, GATE:PLAN)\n' > "$PROJECT_ROOT/.autoflow/.t140-empty.md"; bash "$ROUTE" replay "$PROJECT_ROOT/.autoflow/.t140-empty.md" >/dev/null 2>&1; echo $?; rm -f "$PROJECT_ROOT/.autoflow/.t140-empty.md")"

echo "=== 3. hook Gate 5 ==="
mk_state() { # <dir> <remedy_class or ''>
  local d="$1" rc="$2" rcline=""
  mkdir -p "$d/.autoflow"
  [[ -n "$rc" ]] && rcline="\"remedy_class\": \"$rc\","
  cat > "$d/.autoflow/issue-140.json" <<JSON
{ "active": true, "issue": "#140",
  "phases": {
    "gate_hypothesis_cause": { "verdict": "skipped (feat issue)" },
    "gate_quality": { $rcline "scores": { "Completeness": 8, "Doc updates": 6 } } } }
JSON
}
DOC=$(mktemp -d); mk_state "$DOC" doc
run_hook_stderr 2 "requires the sweep record" "doc remedy, no sweep record → git commit denied" "$DOC" "$(bash_json 'git commit -m "docs: x"')"
run_hook_stderr 2 "requires the sweep record" "doc remedy, chained commit → denied (boundary-anchored)" "$DOC" "$(bash_json 'cd docs && git -c user.name=x commit -m x')"
run_hook 0 "doc remedy, git status → ungated" "$DOC" "$(bash_json 'git status')"
run_hook 0 "doc remedy, git add → ungated" "$DOC" "$(bash_json 'git add -A')"
printf '## Command\n\n## Output\n\n' > "$DOC/.autoflow/issue-140-remedy-sweep.md"
run_hook_stderr 2 "requires the sweep record" "sweep record with empty sections → still denied" "$DOC" "$(bash_json 'git commit -m x')"
printf '## Command\ngrep -rn CONVERGED docs | grep -v AC_CHANGE\n' > "$DOC/.autoflow/issue-140-remedy-sweep.md"
run_hook_stderr 2 "requires the sweep record" "sweep record with Command only (no Output) → denied" "$DOC" "$(bash_json 'git commit -m x')"
printf '## Command\ngrep -rn CONVERGED docs | grep -v AC_CHANGE\n\n## Output\ndocs/a.md:3: …\n' > "$DOC/.autoflow/issue-140-remedy-sweep.md"
run_hook 0 "sweep record complete → git commit allowed" "$DOC" "$(bash_json 'git commit -m x')"
run_hook_stderr 2 "git push requires AUDIT pass" "remedy_class key does not make the state MALFORMED (push still reaches the score gate)" "$DOC" "$(bash_json 'git push')"

TEST=$(mktemp -d); mk_state "$TEST" test
run_hook 0 "remedy_class=test → git commit ungated" "$TEST" "$(bash_json 'git commit -m x')"
NONE=$(mktemp -d); mk_state "$NONE" ""
run_hook 0 "no remedy_class → git commit ungated" "$NONE" "$(bash_json 'git commit -m x')"

# latest-cycle resolution: a base-cycle `doc` superseded by a fix_regression
# record with no remedy_class reads as "no class" — same walk as check_scores.
NEST=$(mktemp -d); mkdir -p "$NEST/.autoflow"
cat > "$NEST/.autoflow/issue-140.json" <<'JSON'
{ "active": true, "issue": "#140",
  "phases": { "gate_hypothesis_cause": { "verdict": "skipped (feat issue)" },
              "gate_quality": { "remedy_class": "doc", "scores": { "Doc updates": 6 } } },
  "fix_regression": { "phases": { "gate_quality": { "scores": { "Doc updates": 8 } } } } }
JSON
run_hook 0 "doc class superseded by a later cycle's record → ungated" "$NEST" "$(bash_json 'git commit -m x')"

rm -rf "$DOC" "$TEST" "$NONE" "$NEST"

echo
echo "Tests: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
