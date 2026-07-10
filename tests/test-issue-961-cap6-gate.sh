#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: AC-961-3 — cap-6 -> FAIL execution guard (issue #961, feature-AC6)
# =============================================================================
# Verifies .autoflow/issue-961-verification-design.md §AC3 / §4.2: the
# pre-existing `check_scores` `min < 7` branch (check-autoflow-gate.sh:284-311)
# already turns any single item capped at 6 into a gate FAIL, via the
# each-item >= 7 rule. ADR-0016 relies on this mechanism to enforce the
# ADR-conformance cap that issue #961 wires into the rubric prose (AC1/AC2).
# This guard is a REGRESSION test for that pre-existing mechanism — it fixes
# nothing and the hook is never edited (confirmed by CI/VALIDATE `git diff
# --exit-code` on .claude/hooks/check-autoflow-gate.sh, out of this file's
# scope per the feature design AC4 invariant).
#
# Self-contained (NOT an extension of tests/test-gate-hardening.sh, which
# defines only `run_hook` (exit-code), not `run_hook_stderr` — verified
# `grep -nE '^run_hook' tests/test-gate-hardening.sh` returns `run_hook`
# alone). This driver copies the `run_hook_stderr` helper (defined upstream in
# tests/test-issue-223-schema-hook-contract.sh:51 and
# tests/test-issue-245-schema-validation.sh:62) plus the `agent_json` /
# `bash_json` builders from tests/test-gate-hardening.sh:39-50, so the deny is
# asserted on the score-branch stderr message, not merely on exit code — an
# implementation-role Agent spawn is denied by the hook for several
# independent causes (missing model, undeclared role, GATE:PLAN not passed),
# so exit-code-only cannot prove the cap-6 attribution.
#
# RED expectation (this commit): this file is new, so both the deny and allow
# cases below already exercise pre-existing hook behavior — they are expected
# to PASS immediately (the guard proves a mechanism that already exists; see
# verification design §AC3 "Design note" and §4 item 2: "must all fail/error
# before the doc edits + guard land (no prose to match, guard absent)" — that
# clause governs the conformance-suite doc greps (AC-961-1/-2/-5/-7), NOT this
# behavioral guard, which is classified in this doc's §2 summary table as
# `Testability: High` / fully deterministic and has no doc-prose dependency.
# Both fixtures below are exercised at RED time to confirm the guard itself
# is correctly wired (PASS now) before the ADR-conformance prose lands.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$PROJECT_ROOT/.claude/hooks/check-autoflow-gate.sh"

PASS=0
FAIL=0

# --- Helpers (copied per feature design §6 / verification §4.2) ------------

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

# run_hook_stderr <expected_exit> <expected_reason_substr> <desc> <project_dir> <json>
# Copied verbatim from tests/test-issue-223-schema-hook-contract.sh:51-69.
run_hook_stderr() {
  local expected="$1" reason_substr="$2" desc="$3" pdir="$4" json="$5"
  local actual stderr_out
  stderr_out=$(mktemp)
  actual=$(printf '%s' "$json" | CLAUDE_PROJECT_DIR="$pdir" bash "$HOOK" >/dev/null 2>"$stderr_out"; echo $?)
  local ok=1
  [[ "$actual" != "$expected" ]] && ok=0
  if [[ $ok -eq 1 ]] && ! grep -qF "$reason_substr" "$stderr_out"; then
    ok=0
  fi
  rm -f "$stderr_out"
  if [[ $ok -eq 1 ]]; then
    echo "  PASS: $desc (exit $actual, reason contains '$reason_substr')"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected exit $expected w/ reason '$reason_substr', got exit $actual)"
    FAIL=$((FAIL + 1))
  fi
}

bash_json() { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(printf '%s' "$1" | jq -Rs .)"; }
# agent_json carries an explicit declared role + model, so the fixture is
# otherwise-valid — the deny (on CAP6_PLAN) or allow (on the raised control)
# is attributable ONLY to the score cap, not to a missing-model or
# undeclared-role deny (verification §AC3 fixture-completeness, open concern C4).
agent_json() { printf '{"tool_name":"Agent","tool_input":{"subagent_type":%s,"prompt":%s,"model":%s}}' "$(printf '%s' "$1" | jq -Rs .)" "$(printf '%s' "$2" | jq -Rs .)" "$(printf '%s' "${3:-sonnet}" | jq -Rs .)"; }

# --- Fixtures ----------------------------------------------------------------

# CAP6_PLAN: active issue, gate_hypothesis_cause already skipped (feat issue,
# per feature §6 / verification §AC3 fixture-completeness) so an
# implementation-role Agent spawn deny is attributable to GATE:PLAN's own cap,
# not to a missing GATE:HYPOTHESIS pass. gate_plan.scores has exactly one item
# = 6, all others >= 7 (avg still >= 7.5 to isolate the min<7 branch alone).
CAP6_PLAN=$(mktemp -d)
mkdir -p "$CAP6_PLAN/.autoflow"
cat > "$CAP6_PLAN/.autoflow/issue-961.json" <<'EOF'
{ "active": true, "issue": "#961",
  "phases": {
    "gate_hypothesis_cause": { "verdict": "skipped (feat issue)" },
    "gate_plan": { "scores": {
      "Feasibility":  {"score": 8},
      "Dependencies": {"score": 8},
      "Scope":        {"score": 6},
      "Security":     {"score": 8},
      "Test plan":    {"score": 8}
    } } } }
EOF

# CAP6_PLAN_ALLOW: same fixture with the capped item raised to 7 (all >= 7,
# avg >= 7.5) — the regression discriminator proving the FAIL above is caused
# specifically by the 6-cap, not by any other fixture property.
CAP6_PLAN_ALLOW=$(mktemp -d)
mkdir -p "$CAP6_PLAN_ALLOW/.autoflow"
cat > "$CAP6_PLAN_ALLOW/.autoflow/issue-961.json" <<'EOF'
{ "active": true, "issue": "#961",
  "phases": {
    "gate_hypothesis_cause": { "verdict": "skipped (feat issue)" },
    "gate_plan": { "scores": {
      "Feasibility":  {"score": 8},
      "Dependencies": {"score": 8},
      "Scope":        {"score": 7},
      "Security":     {"score": 8},
      "Test plan":    {"score": 8}
    } } } }
EOF

# CAP6_QUALITY: active issue, audit already passing, gate_quality.scores has
# exactly one item = 6 (Fit), all others >= 7.
CAP6_QUALITY=$(mktemp -d)
mkdir -p "$CAP6_QUALITY/.autoflow"
cat > "$CAP6_QUALITY/.autoflow/issue-961.json" <<'EOF'
{ "active": true, "issue": "#961",
  "phases": {
    "audit": { "scores": {
      "Authn/Authz":      {"score": 8},
      "Input validation": {"score": 8},
      "Data exposure":    {"score": 8},
      "Infra isolation":  {"score": 8},
      "Dependencies":     {"score": 8}
    } },
    "gate_quality": { "scores": {
      "Completeness":            {"score": 8},
      "Quality":                 {"score": 8},
      "Test coverage":           {"score": 8},
      "Test quality":            {"score": 8},
      "Security":                {"score": 8},
      "Fit":                     {"score": 6},
      "Impact scope":            {"score": 8},
      "Minimal implementation":  {"score": 8},
      "Commit conventions":      {"score": 8},
      "Doc updates":             {"score": 8}
    } } } }
EOF

# CAP6_QUALITY_ALLOW: same fixture, capped item (Fit) raised to 7.
CAP6_QUALITY_ALLOW=$(mktemp -d)
mkdir -p "$CAP6_QUALITY_ALLOW/.autoflow"
cat > "$CAP6_QUALITY_ALLOW/.autoflow/issue-961.json" <<'EOF'
{ "active": true, "issue": "#961",
  "phases": {
    "audit": { "scores": {
      "Authn/Authz":      {"score": 8},
      "Input validation": {"score": 8},
      "Data exposure":    {"score": 8},
      "Infra isolation":  {"score": 8},
      "Dependencies":     {"score": 8}
    } },
    "gate_quality": { "scores": {
      "Completeness":            {"score": 8},
      "Quality":                 {"score": 8},
      "Test coverage":           {"score": 8},
      "Test quality":            {"score": 8},
      "Security":                {"score": 8},
      "Fit":                     {"score": 7},
      "Impact scope":            {"score": 8},
      "Minimal implementation":  {"score": 8},
      "Commit conventions":      {"score": 8},
      "Doc updates":             {"score": 8}
    } } } }
EOF

trap 'rm -rf "$CAP6_PLAN" "$CAP6_PLAN_ALLOW" "$CAP6_QUALITY" "$CAP6_QUALITY_ALLOW"' EXIT

# --- AC-961-3 cases ----------------------------------------------------------

echo "AC-961-3 — cap-6 -> FAIL guard: GATE:PLAN surface (implementation-role Agent spawn)"
run_hook_stderr 2 "each item must be ≥ 7" \
  "declared implementer, Scope capped at 6 → denied on the score-branch reason (not model/role)" \
  "$CAP6_PLAN" "$(agent_json 'autoflow-implementer' 'make the failing tests pass' 'sonnet')"
run_hook 0 \
  "declared implementer, Scope raised to 7 (all >= 7, avg >= 7.5) → allowed (discriminator)" \
  "$CAP6_PLAN_ALLOW" "$(agent_json 'autoflow-implementer' 'make the failing tests pass' 'sonnet')"

echo "AC-961-3 — cap-6 -> FAIL guard: GATE:QUALITY surface (git push / gh pr create)"
run_hook_stderr 2 "each item must be ≥ 7" \
  "git push, Fit capped at 6 → denied on the score-branch reason" \
  "$CAP6_QUALITY" "$(bash_json 'git push -u origin dev/issue-961')"
run_hook_stderr 2 "each item must be ≥ 7" \
  "gh pr create, Fit capped at 6 → denied on the score-branch reason" \
  "$CAP6_QUALITY" "$(bash_json 'gh pr create -t t -b b')"
run_hook 0 \
  "git push, Fit raised to 7 (all >= 7, avg >= 7.5) → allowed (discriminator)" \
  "$CAP6_QUALITY_ALLOW" "$(bash_json 'git push -u origin dev/issue-961')"
run_hook 0 \
  "gh pr create, Fit raised to 7 (all >= 7, avg >= 7.5) → allowed (discriminator)" \
  "$CAP6_QUALITY_ALLOW" "$(bash_json 'gh pr create -t t -b b')"

echo "=============================="
echo "Results: $((PASS + FAIL)) total, $PASS passed, $FAIL failed"
echo "=============================="
[[ $FAIL -eq 0 ]]
