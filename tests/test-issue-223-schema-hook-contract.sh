#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: check-autoflow-gate.sh CONTRACT (issue #223)
# =============================================================================
# Verifies the gate hook's literals / call-sites equal the canonical source:
#   Class A — static correspondence (path/threshold/key) vs gate-schema.json
#             and autoflow-state-canonical.json
#   Class B — behavioral drive of the hook (canonical + mutated fixtures)
#             covering Gate 1 + Gate 2 (hole in test-gate-hardening.sh) and
#             the five drift scenarios (a)-(e) from the scope note.
#
# Single source of truth: tests/fixtures/gate-schema.json (thresholds, gated
# keys, security keys, jq paths).  The test reads these values via jq and
# asserts the hook's in-script literals equal the declared values — it does
# NOT hardcode 7.5 / 7 / 3 / key names in the test body.
#
# Sibling tests left intact (reuses run_hook / mktemp convention from
# tests/test-gate-hardening.sh — see lines 21-60 of that file).
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$PROJECT_ROOT/.claude/hooks/check-autoflow-gate.sh"
SCHEMA="$PROJECT_ROOT/tests/fixtures/gate-schema.json"
CANON_STATE="$PROJECT_ROOT/tests/fixtures/autoflow-state-canonical.json"

PASS=0
FAIL=0

# ---------------------------------------------------------------------------
# Helpers (same contract as test-gate-hardening.sh lines 21-31)
# ---------------------------------------------------------------------------

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
# Like run_hook but also asserts stderr contains expected_reason_substr.
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

bash_json()  { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(printf '%s' "$1" | jq -Rs .)"; }
agent_json() {
  # Carries an explicit model so these state-gate cases are unaffected by the
  # Section-1b model-declaration deny (issue #475) — that deny has its own
  # coverage in test-gate-hardening.sh.
  local prompt="$1" subtype="${2:-}"
  printf '{"tool_name":"Agent","tool_input":{"prompt":%s,"subagent_type":%s,"model":"sonnet"}}' \
    "$(printf '%s' "$prompt" | jq -Rs .)" \
    "$(printf '%s' "$subtype" | jq -Rs .)"
}

# assert_static <desc> <condition_exit>
# Wrap a pure-bash conditional that returns 0=pass / nonzero=fail.
assert_static() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

# assert_eq <desc> <actual> <expected>
assert_eq() {
  local desc="$1" actual="$2" expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  PASS: $desc (=$actual)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected '$expected', got '$actual')"
    FAIL=$((FAIL + 1))
  fi
}

# ---------------------------------------------------------------------------
# Pre-flight: canonical source files must exist (AC1 entry condition)
# If they are absent everything below is RED by design — GREEN creates them.
# ---------------------------------------------------------------------------
echo "=== Pre-flight: canonical source files ==="
if [[ ! -f "$SCHEMA" ]]; then
  echo "  FAIL: tests/fixtures/gate-schema.json not found — canonical source absent (RED as designed)"
  FAIL=$((FAIL + 1))
fi
if [[ ! -f "$CANON_STATE" ]]; then
  echo "  FAIL: tests/fixtures/autoflow-state-canonical.json not found — canonical source absent (RED as designed)"
  FAIL=$((FAIL + 1))
fi

# If either fixture is absent, every subsequent assertion would produce
# misleading noise (jq errors, false-PASS on empty strings, etc.).
# Bail early with the results so far — the RED state is already confirmed.
if [[ ! -f "$SCHEMA" ]] || [[ ! -f "$CANON_STATE" ]]; then
  echo ""
  echo "=============================="
  echo "Results: $((PASS + FAIL)) total, $PASS passed, $FAIL failed"
  echo "=============================="
  exit 1
fi

# ---------------------------------------------------------------------------
# Load schema-derived values (single source — never hardcoded below)
# ---------------------------------------------------------------------------
AVG_MIN=$(jq -r '.thresholds.avg_min'            "$SCHEMA")   # 7.5
ITEM_MIN=$(jq -r '.thresholds.item_min'          "$SCHEMA")   # 7
SEC_MAX=$(jq -r '.thresholds.security_block_max' "$SCHEMA")   # 3
# bash-3.2-portable array read (no mapfile/readarray — macOS default bash is 3.2; #190).
# Initialize to () BEFORE the loop so `set -u` is satisfied even on an empty read.
GATED_KEYS=()
while IFS= read -r line; do GATED_KEYS+=("$line"); done < <(jq -r '.gated_phase_keys[]' "$SCHEMA")
SEC_KEYS=()
while IFS= read -r line; do SEC_KEYS+=("$line"); done < <(jq -r '.security_keys[]' "$SCHEMA")
PATH_ACTIVE=$(jq -r '.paths.active'  "$SCHEMA")   # .active
PATH_VERDICT=$(jq -r '.paths.verdict' "$SCHEMA")  # .phases.gate_hypothesis_cause.verdict

# ---------------------------------------------------------------------------
# ════════════════════════════════════════════════════════════════════════════
# CLASS A — Static contract assertions
# ════════════════════════════════════════════════════════════════════════════

echo ""
echo "=== CLASS A: Static correspondence (hook literals ↔ gate-schema.json) ==="

# ---
# A1 — Threshold numeric-equality (DCR-1 form, AC4)
# Extract each comparison literal from the hook with grep -Eo and assert it
# numerically equals the schema-declared value.
# Pattern rationale (verified against live hook):
#   avg: `$avg < 7.5`   → extract the number after "$avg < "
#   min: `$min < 7`     → extract after "$min < "  (anchored to avoid matching 7.5)
#   sec: `$sec <= 3`    → extract after "$sec <= "
# The Eo patterns are anchored to the operator so '7' does not collide with '7.5'.
# ---
echo ""
echo "A1 — threshold numeric-equality vs gate-schema.json"

HOOK_AVG=$(grep -Eo '\$avg < [0-9]+(\.[0-9]+)?' "$HOOK" | grep -Eo '[0-9]+(\.[0-9]+)?$' | head -1)
HOOK_MIN=$(grep -Eo '\$min < [0-9]+(\.[0-9]+)?' "$HOOK" | grep -Eo '[0-9]+(\.[0-9]+)?$' | head -1)
HOOK_SEC=$(grep -Eo '\$sec <= [0-9]+(\.[0-9]+)?' "$HOOK" | grep -Eo '[0-9]+(\.[0-9]+)?$' | head -1)

assert_eq "A1a: hook avg threshold equals schema avg_min"            "$HOOK_AVG" "$AVG_MIN"
assert_eq "A1b: hook item-min threshold equals schema item_min"      "$HOOK_MIN" "$ITEM_MIN"
assert_eq "A1c: hook security threshold equals schema security_block_max" "$HOOK_SEC" "$SEC_MAX"

# ---
# A2 — Phase-key quoted call-argument grep (AC2)
# For each schema-derived gated key, assert the hook references it as the
# SECOND quoted argument of a block_with_scores call (not as a bare substring).
# Precision is load-bearing: gate_hypothesis_cause appears 3× in the hook
# (comment L168, verdict jq path L169, gating call L172); a bare grep would
# pass even if the L172 gating call were deleted.
# Pattern: block_with_scores .*"<key>"
# ---
echo ""
echo "A2 — gated phase keys appear as block_with_scores call-arguments"

for key in "${GATED_KEYS[@]}"; do
  assert_static "A2: '$key' is a block_with_scores quoted arg in hook" \
    grep -qE "block_with_scores .*\"${key}\"" "$HOOK"
done

# A2-bijection: the schema set must EQUAL the set of keys the hook actually
# gates (not merely schema ⊆ hook). Extract the SET of phase keys the hook
# passes to block_with_scores (last quoted call-argument per call line; the
# `block_with_scores() {` definition line has no space+quote so it is not
# matched), dedupe+sort, and compare to the schema's gated_phase_keys set.
# This fails if the schema DROPS a key the hook gates (under-declaration) OR
# LISTS a key the hook does not gate (over-declaration) — matching A1's
# bidirectional bar.
HOOK_GATED_SET=$(grep -E 'block_with_scores[[:space:]]+"' "$HOOK" \
  | sed -E 's/.*"([^"]*)"[[:space:]]*$/\1/' \
  | sort -u)
SCHEMA_GATED_SET=$(jq -r '.gated_phase_keys[]' "$SCHEMA" | sort -u)
assert_eq "A2-bijection: schema gated_phase_keys set EQUALS hook's gated call-arg set" \
  "$HOOK_GATED_SET" "$SCHEMA_GATED_SET"

# Also assert the canonical state fixture's .phases is a superset of gated keys.
for key in "${GATED_KEYS[@]}"; do
  assert_static "A2-fixture: canonical state has .phases['$key']" \
    bash -c "jq -e --arg k '$key' '.phases | has(\$k)' '$CANON_STATE' > /dev/null"
done

# Assert gate_hypothesis_structure is NOT in gated_phase_keys (DCR-2 — ungated key).
STRUCT_IN_SCHEMA=$(jq -r '.gated_phase_keys | map(select(. == "gate_hypothesis_structure")) | length' "$SCHEMA")
assert_eq "A2-ungated: gate_hypothesis_structure not in schema gated_phase_keys" \
  "$STRUCT_IN_SCHEMA" "0"
# But it IS in the canonical fixture (schema fidelity).
assert_static "A2-ungated-fixture: canonical state carries gate_hypothesis_structure" \
  bash -c "jq -e '.phases | has(\"gate_hypothesis_structure\")' '$CANON_STATE' > /dev/null"

# ---
# A3 — Score-path / walk (AC3, scope b)
# The hook must reference:
#   select(has("phases"))          — recursive walk selector
#   .phases[$phase].scores         — parameterized score path
# ---
echo ""
echo "A3 — score-path / walk literals present in hook"

assert_static 'A3a: hook contains select(has("phases"))' \
  grep -qF 'select(has("phases"))' "$HOOK"
assert_static 'A3b: hook contains .phases[$phase].scores' \
  grep -qF '.phases[$phase].scores' "$HOOK"

# ---
# A4 — Verdict path (AC5, scope d)
# Static: hook references .phases.gate_hypothesis_cause.verdict
# Schema's paths.verdict equals that literal.
# Canonical fixture carries a value at that jq path.
# ---
echo ""
echo "A4 — verdict path correspondence"

VERDICT_PATH_LITERAL='.phases.gate_hypothesis_cause.verdict'
assert_static "A4a: hook contains '$VERDICT_PATH_LITERAL'" \
  grep -qF "$VERDICT_PATH_LITERAL" "$HOOK"
assert_eq "A4b: schema paths.verdict equals '$VERDICT_PATH_LITERAL'" \
  "$PATH_VERDICT" "$VERDICT_PATH_LITERAL"
CANON_VERDICT=$(jq -r '.phases.gate_hypothesis_cause.verdict // "MISSING"' "$CANON_STATE")
assert_static "A4c: canonical fixture has verdict at .phases.gate_hypothesis_cause.verdict" \
  bash -c '[[ '"$(printf '%q' "$CANON_VERDICT")"' != "MISSING" ]]'

# ---
# A5 — Active-flag path (AC6, scope e)
# Hook must reference .active (and // false default).
# Schema's paths.active equals .active.
# Canonical fixture has a top-level .active boolean.
# ---
echo ""
echo "A5 — active-flag path correspondence"

assert_static "A5a: hook contains '.active // false'" \
  grep -qF '.active // false' "$HOOK"
assert_eq "A5b: schema paths.active equals '.active'" \
  "$PATH_ACTIVE" ".active"
CANON_ACTIVE_TYPE=$(jq -r '.active | type' "$CANON_STATE")
assert_eq "A5c: canonical fixture .active is boolean" \
  "$CANON_ACTIVE_TYPE" "boolean"

# ---
# A6 — Security dual-key (DCR-3, scope c)
# For each entry in schema security_keys (["security","보안"]),
# assert the hook source references it.
# ---
echo ""
echo "A6 — security dual-key (English + Korean) present in hook"

for sk in "${SEC_KEYS[@]}"; do
  assert_static "A6: hook contains security key '$sk'" \
    grep -qF "\"${sk}\"" "$HOOK"
done

# A6-bijection: the schema security_keys set must EQUAL the set of keys the
# hook actually reads on its security-extraction line `.["security"] // .["보안"]`
# (not merely schema ⊆ hook). Extract every `.["<key>"]` from that line,
# dedupe+sort, and compare to the schema's security_keys set. This fails if
# the schema DROPS the Korean fallback the hook still reads OR LISTS a key the
# hook does not read — bidirectional, matching A1/A2-bijection.
HOOK_SEC_SET=$(grep -F '.["security"]' "$HOOK" \
  | grep -oE '\.\["[^"]*"\]' \
  | sed -E 's/^\.\["//; s/"\]$//' \
  | sort -u)
SCHEMA_SEC_SET=$(jq -r '.security_keys[]' "$SCHEMA" | sort -u)
assert_eq "A6-bijection: schema security_keys set EQUALS hook's security-line key set" \
  "$HOOK_SEC_SET" "$SCHEMA_SEC_SET"

# ---------------------------------------------------------------------------
# ════════════════════════════════════════════════════════════════════════════
# CLASS B — Behavioral assertions (run_hook pattern, AC7 + coverage holes)
# ════════════════════════════════════════════════════════════════════════════

echo ""
echo "=== CLASS B: Behavioral drive (canonical + mutated fixtures) ==="

# ---
# Staging helper: create a temp dir with .autoflow/issue-N.json from JSON.
# Never writes into the repo's real .autoflow/.
# ---
# Single parent-shell work root: every staged fixture dir is created UNDER it,
# so one trap cleans them all. (The previous `TMPDIRS+=(...)` append never
# reached the parent shell — `DIR=$(stage_fixture ...)` runs in a subshell, so
# the array stayed empty and the trap deleted nothing → temp-dir leak. Codex
# PR #240 Medium. The single-root trap is subshell-proof.)
WORKROOT="$(mktemp -d)" || { echo "mktemp failed (WORKROOT)" >&2; exit 1; }
trap 'rm -rf "$WORKROOT"' EXIT

stage_fixture() {
  # stage_fixture <json_content> → prints the project_dir path (under WORKROOT)
  local content="$1"
  local d
  d="$(mktemp -d -p "$WORKROOT")" || { echo "mktemp -d -p failed in stage_fixture" >&2; return 1; }
  mkdir -p "$d/.autoflow"
  printf '%s' "$content" > "$d/.autoflow/issue-223.json"
  echo "$d"
}

# stage_multi <name1> <json1> <name2> <json2> → prints the project_dir path,
# holding TWO state files side by side (issue #843 AC2: multi-active fixtures
# need more than stage_fixture's single fixed-name file).
stage_multi() {
  local name1="$1" json1="$2" name2="$3" json2="$4"
  local d
  d="$(mktemp -d -p "$WORKROOT")" || { echo "mktemp -d -p failed in stage_multi" >&2; return 1; }
  mkdir -p "$d/.autoflow"
  printf '%s' "$json1" > "$d/.autoflow/$name1"
  printf '%s' "$json2" > "$d/.autoflow/$name2"
  echo "$d"
}

# Read the canonical fixture text once.
CANON_JSON=$(cat "$CANON_STATE")

# ---
# B1 — Canonical fixture (passing scores) + git push → exit 0 (Gate 3 PASS)
# ---
echo ""
echo "B1 — canonical fixture: git push passes all gates"
B1_DIR=$(stage_fixture "$CANON_JSON")
run_hook 0 "B1: git push dev branch w/ canonical passing scores" \
  "$B1_DIR" "$(bash_json 'git push origin dev/223-contract')"

# ---
# B2 — Canonical fixture + gh pr create → exit 0 (Gate 4 PASS)
# ---
echo ""
echo "B2 — canonical fixture: gh pr create passes all gates"
B2_DIR=$(stage_fixture "$CANON_JSON")
run_hook 0 "B2: gh pr create w/ canonical passing scores" \
  "$B2_DIR" "$(bash_json 'gh pr create -t "contract test" -b "body"')"

# ---
# B3 — Gate-2 coverage (hole in test-gate-hardening.sh): feat-mode fixture
# with empty gate_plan scores + implementation Agent prompt → exit 2.
# Gate 2 fires when GATE:PLAN scores are empty and prompt matches implement/.
# ---
echo ""
echo "B3 — Gate 2 (implementation Agent): empty gate_plan blocks"
B3_JSON=$(jq '.phases.gate_plan.scores = {}' <<< "$CANON_JSON")
B3_DIR=$(stage_fixture "$B3_JSON")
run_hook 2 "B3: implementation Agent blocked (empty gate_plan scores)" \
  "$B3_DIR" "$(agent_json 'implement the fix and commit' 'autoflow-implementer')"

# Positive pair: passing gate_plan → exits 0.
B3P_DIR=$(stage_fixture "$CANON_JSON")
run_hook 0 "B3-pass: implementation Agent allowed w/ passing gate_plan" \
  "$B3P_DIR" "$(agent_json 'implement the fix and commit' 'autoflow-implementer')"

# ---
# B4 — Renamed phase-key (gate_quality → gate_qualityX): Gate 3 blocks
# with "evaluation not run" because hook can no longer find the scores.
# Demonstrates the runtime consequence of the drift A2 catches statically.
# ---
echo ""
echo "B4 — renamed phase key (gate_quality→gate_qualityX): git push blocks"
B4_JSON=$(jq '
  .phases.gate_qualityX = .phases.gate_quality |
  del(.phases.gate_quality)
' <<< "$CANON_JSON")
B4_DIR=$(stage_fixture "$B4_JSON")
run_hook 2 "B4: git push blocked after gate_quality renamed (drift)" \
  "$B4_DIR" "$(bash_json 'git push origin dev/223-contract')"

# ---
# B5 — Bare-number score form (if type=="object" then .score else . end)
# A fixture using bare integers (not {"score":N} objects) must also PASS.
# Pins the normalization at L109 so a future edit breaking bare-number form
# is caught.
# ---
echo ""
echo "B5 — bare-number score form passes normalization"
B5_JSON=$(jq '
  .phases.gate_plan.scores    = {"a":8,"b":8} |
  .phases.audit.scores        = {"a":8,"b":8} |
  .phases.gate_quality.scores = {"a":8,"b":8}
' <<< "$CANON_JSON")
B5_DIR=$(stage_fixture "$B5_JSON")
run_hook 0 "B5: git push passes w/ bare-number scores" \
  "$B5_DIR" "$(bash_json 'git push origin dev/223-contract')"

# ---
# B6 — Security dual-key behavior (DCR-3): both "security" and "보안" keys
# trigger the security block with the correct reason string.
# Assertion is on the REASON string, not merely exit 2, because sec ≤ 3
# also satisfies $min < 7 — asserting the reason confirms dual-key
# extraction is load-bearing (verified: $sec <= 3 evaluated before $min < 7).
# ---
echo ""
echo "B6 — security dual-key: both 'security' and '보안' trigger security block reason"

# English key "security" with score ≤ security_block_max
B6_EN_JSON=$(jq --argjson sec "$SEC_MAX" '
  .phases.gate_quality.scores = {"security": {"score": $sec}}
' <<< "$CANON_JSON")
B6_EN_DIR=$(stage_fixture "$B6_EN_JSON")
run_hook_stderr 2 "security score" \
  "B6a: English key 'security' score=$SEC_MAX triggers security block reason" \
  "$B6_EN_DIR" "$(bash_json 'git push origin dev/223-contract')"

# Korean key "보안" with score ≤ security_block_max
B6_KO_JSON=$(jq --argjson sec "$SEC_MAX" '
  .phases.gate_quality.scores = {"보안": {"score": $sec}}
' <<< "$CANON_JSON")
B6_KO_DIR=$(stage_fixture "$B6_KO_JSON")
run_hook_stderr 2 "security score" \
  "B6b: Korean key '보안' score=$SEC_MAX triggers security block reason" \
  "$B6_KO_DIR" "$(bash_json 'git push origin dev/223-contract')"

# ---
# B7 — Verdict skip-bypass behavior, Gate 1 (AC5 behavioral half, scope d)
# Feat fixture (verdict contains "skip") + empty gate_hypothesis_cause.scores
# + planning-keyword Agent prompt → exit 0 (bypass).
# Bug fixture (verdict "pending") + same conditions → exit 2 (gate fires).
# Delta proves the skip-substring semantics and verdict path are load-bearing.
# ---
echo ""
echo "B7 — verdict skip-bypass: feat skips Gate 1, bug fires Gate 1"

PLAN_PROMPT='discuss the design approach'

B7_FEAT_JSON=$(jq '
  .phases.gate_hypothesis_cause.verdict = "skipped (feat issue)" |
  .phases.gate_hypothesis_cause.scores  = {}
' <<< "$CANON_JSON")
B7_FEAT_DIR=$(stage_fixture "$B7_FEAT_JSON")
run_hook 0 "B7a: feat verdict='skipped' → Gate 1 bypassed (exit 0)" \
  "$B7_FEAT_DIR" "$(agent_json "$PLAN_PROMPT" 'autoflow-planner')"

B7_BUG_JSON=$(jq '
  .phases.gate_hypothesis_cause.verdict = "pending" |
  .phases.gate_hypothesis_cause.scores  = {}
' <<< "$CANON_JSON")
B7_BUG_DIR=$(stage_fixture "$B7_BUG_JSON")
run_hook 2 "B7b: bug verdict='pending' + empty scores → Gate 1 fires (exit 2)" \
  "$B7_BUG_DIR" "$(agent_json "$PLAN_PROMPT" 'autoflow-planner')"

# ---
# B8 — Active-flag gating on/off behavior (AC6 behavioral half, scope e)
# active:false variant + git push → exit 0 (no gating, hook short-circuits).
# Proves .active is the load-bearing gating switch — complementing A5.
# ---
echo ""
echo "B8 — active-flag: active:false disables gating"

B8_INACTIVE_JSON=$(jq '.active = false | .phases.audit.scores = {} | .phases.gate_quality.scores = {}' <<< "$CANON_JSON")
B8_INACTIVE_DIR=$(stage_fixture "$B8_INACTIVE_JSON")
run_hook 0 "B8a: active:false + empty scores → no gating (exit 0)" \
  "$B8_INACTIVE_DIR" "$(bash_json 'git push origin dev/223-contract')"

# Paired positive: active:true + empty scores → gating fires (exit 2).
B8_ACTIVE_JSON=$(jq '.active = true | .phases.audit.scores = {} | .phases.gate_quality.scores = {}' <<< "$CANON_JSON")
B8_ACTIVE_DIR=$(stage_fixture "$B8_ACTIVE_JSON")
run_hook 2 "B8b: active:true + empty scores → gating fires (exit 2)" \
  "$B8_ACTIVE_DIR" "$(bash_json 'git push origin dev/223-contract')"

# ---
# B9 — Score-path SUB-KEY move (AC3, scope b — verification design L49)
# Move a gated phase's `scores` sub-key to `score_data` (keeping audit.scores
# valid/passing) → the hook reads .phases["gate_quality"].scores which is now
# absent → empty → "evaluation not run" → git push blocks (exit 2 + reason).
# This proves the `.scores` SUB-KEY path (not just the phase key, which B4
# covers under scope a) is the contract — a score-path move is caught
# behaviorally, complementing static A3. Positive control is B1.
# ---
echo ""
echo "B9 — score-path sub-key move (gate_quality.scores→score_data): git push blocks"
B9_JSON=$(jq '
  .phases.gate_quality.score_data = .phases.gate_quality.scores |
  del(.phases.gate_quality.scores)
' <<< "$CANON_JSON")
B9_DIR=$(stage_fixture "$B9_JSON")
run_hook_stderr 2 "evaluation not run" \
  "B9: git push blocked after gate_quality.scores moved to score_data (score-path drift)" \
  "$B9_DIR" "$(bash_json 'git push origin dev/223-contract')"

# ---
# B10 — AC1 (issue #843): nested fix_regression empty-scores discriminator
# ("stale-cycle score fallback"). The buggy check_scores collects every
# cycle's phases[$phase].scores, DROPS the empty ones, then takes `last` —
# so a most-recent regression cycle that recorded the phase but has not yet
# scored it (`scores == {}`) is silently skipped and an OLDER cycle's PASS is
# used instead. gate_quality is given a stable root-level PASS in every B10
# fixture so it does not itself gate the push — the assertions below isolate
# the AUDIT selection bug specifically (a fixture using only "audit" would
# have gate_quality fail-closed regardless of the AC1 fix, masking the RED).
# ---
echo ""
echo "B10 — AC1: nested fix_regression empty-scores → stale-PASS fallback discriminator"

B10_JSON='{
  "active": true,
  "phases": {
    "audit": {"verdict":"evaluated","scores":{"correctness":9,"security":9}},
    "gate_quality": {"scores": {"a": 8, "b": 8}}
  },
  "fix_regression": {
    "phases": {
      "audit": {"verdict":"pending","scores":{}}
    }
  }
}'
B10_DIR=$(stage_fixture "$B10_JSON")
run_hook_stderr 2 "evaluation not run" \
  "B10: nested fix_regression.audit.scores={} over base audit PASS → git push blocked (RED: today's hook falls back to the base cycle's stale PASS and admits the push)" \
  "$B10_DIR" "$(bash_json 'git push origin dev/843')"

# Positive control (must stay green pre+post): same nesting, but the
# regression's audit scores are a genuine PASS object — proves the fix does
# not over-block a legitimately re-scored regression cycle.
B10_PASS_JSON='{
  "active": true,
  "phases": {
    "audit": {"verdict":"evaluated","scores":{"correctness":9,"security":9}},
    "gate_quality": {"scores": {"a": 8, "b": 8}}
  },
  "fix_regression": {
    "phases": {
      "audit": {"verdict":"evaluated","scores":{"a":8,"b":8}}
    }
  }
}'
B10_PASS_DIR=$(stage_fixture "$B10_PASS_JSON")
run_hook 0 "B10-pass: fix_regression.audit re-scored PASS → git push allowed (no over-block)" \
  "$B10_PASS_DIR" "$(bash_json 'git push origin dev/843')"

# Deadlock-safety positive control + paired fail-closed assertion (AC1,
# load-bearing per feature-design F1 §Deadlock-safety): a regression object
# that re-ran ONLY audit + gate_quality — no `phases.gate_plan` key in the
# regression at all — over a base cycle whose gate_plan already PASSed.
B10_DEADLOCK_JSON='{
  "active": true,
  "phases": {
    "gate_plan":    {"scores": {"a":8,"b":8}},
    "audit":        {"scores": {"a":8,"b":8}},
    "gate_quality": {"scores": {"a":8,"b":8}}
  },
  "fix_regression": {
    "phases": {
      "audit":        {"scores": {}},
      "gate_quality": {"scores": {}}
    }
  }
}'
B10_DEADLOCK_DIR=$(stage_fixture "$B10_DEADLOCK_JSON")
# The gate_plan-gated implementation spawn must NOT deadlock: selection by
# "last cycle that HAS the phases[$phase] key" (not "last cycle overall")
# skips the regression for gate_plan (it never recorded that phase) and
# resolves the base cycle's PASS. Green pre+post — proves no regression.
run_hook 0 "B10-deadlock: gate_plan-gated impl spawn admitted from base PASS (regression never re-ran gate_plan)" \
  "$B10_DEADLOCK_DIR" "$(agent_json 'implement the fix and commit' 'autoflow-implementer')"
# The SAME fixture's audit/gate_quality (empty {} in the regression) must
# fail closed on git push — RED: today's hook falls back to the base cycle's
# PASS for BOTH phases and admits the push.
run_hook_stderr 2 "evaluation not run" \
  "B10-deadlock-fail-closed: same fixture's re-run audit/gate_quality (empty in regression) blocks git push" \
  "$B10_DEADLOCK_DIR" "$(bash_json 'git push origin dev/843')"

# ---
# B11 — AC2 (issue #843): ≥2 active state files → score gate fails closed.
# Today's discovery loop breaks on the lexically-first active file and
# admits the push regardless of which issue it targets. Uses the new
# stage_multi helper (single fixed-name stage_fixture cannot hold two files).
# ---
echo ""
echo "B11 — AC2: multiple active state files → fail closed (multi-active guard)"

B11_FAIL_JSON='{
  "active": true,
  "issue": "#99",
  "phases": {
    "gate_hypothesis_cause": {"verdict":"pending","scores":{}},
    "gate_plan":    {"scores":{"a":8,"b":8}},
    "audit":        {"scores":{"a":8,"b":8}},
    "gate_quality": {"scores":{"a":3,"b":3}}
  }
}'
B11_PASS_JSON='{
  "active": true,
  "issue": "#100",
  "phases": {
    "gate_hypothesis_cause": {"verdict":"pending","scores":{}},
    "gate_plan":    {"scores":{"a":8,"b":8}},
    "audit":        {"scores":{"a":8,"b":8}},
    "gate_quality": {"scores":{"a":9,"b":9}}
  }
}'

# issue-100.json sorts lexically BEFORE issue-99.json (glob order), so
# today's hook picks issue-100 (the PASS file) regardless of the push's
# actual target (#99, the FAIL file) — RED: exits 0 today.
B11_AB_DIR=$(stage_multi "issue-99.json" "$B11_FAIL_JSON" "issue-100.json" "$B11_PASS_JSON")
run_hook_stderr 2 "multiple active" \
  "B11a: issue-99(FAIL)+issue-100(PASS) both active → git push origin dev/99 blocked (RED: today admits via lexically-first issue-100 PASS)" \
  "$B11_AB_DIR" "$(bash_json 'git push origin dev/99')"

# Order-independence: swap which filename carries FAIL vs PASS. Both
# orderings must fail closed post-fix — proves the fix counts active files
# rather than trusting glob order.
B11_BA_DIR=$(stage_multi "issue-99.json" "$B11_PASS_JSON" "issue-100.json" "$B11_FAIL_JSON")
run_hook_stderr 2 "multiple active" \
  "B11b (order-independence): issue-99(PASS)+issue-100(FAIL) both active → git push blocked regardless of glob order" \
  "$B11_BA_DIR" "$(bash_json 'git push origin dev/99')"

# "Active:" line names BOTH active paths (AC2 "두 경로를 명시한 메시지").
B11_STDERR=$(mktemp)
printf '%s' "$(bash_json 'git push origin dev/99')" | \
  CLAUDE_PROJECT_DIR="$B11_AB_DIR" bash "$HOOK" >/dev/null 2>"$B11_STDERR" || true
if grep -qF "Active:" "$B11_STDERR" && grep -qF "issue-99.json" "$B11_STDERR" && grep -qF "issue-100.json" "$B11_STDERR"; then
  echo "  PASS: B11c: stderr 'Active:' line names both issue-99.json and issue-100.json"
  PASS=$((PASS + 1))
else
  echo "  FAIL: B11c: stderr does not name both active paths on an 'Active:' line"
  FAIL=$((FAIL + 1))
fi
rm -f "$B11_STDERR"

# Positive control (green pre+post): exactly one active file + one
# active:false file in the same dir → git push allowed. Proves the guard
# keys on active:true COUNT > 1, not on file count.
B11_POS_DIR=$(stage_multi "issue-1.json" "$CANON_JSON" "issue-2.json" "$(jq '.active = false' <<< "$CANON_JSON")")
run_hook 0 "B11-pos: exactly one active file (+ one active:false sibling) → git push allowed" \
  "$B11_POS_DIR" "$(bash_json 'git push origin dev/1')"

# Gate-surface coverage (feature-design F2 Change 2 decided scope): push,
# PR-create, AND a declared implementation Agent spawn all fail closed.
run_hook_stderr 2 "multiple active" \
  "B11d: gh pr create blocked under ≥2 active files" \
  "$B11_AB_DIR" "$(bash_json 'gh pr create -t "t" -b "b"')"
run_hook_stderr 2 "multiple active" \
  "B11e: implementation Agent spawn (autoflow-implementer) blocked under ≥2 active files" \
  "$B11_AB_DIR" "$(agent_json 'implement the fix and commit' 'autoflow-implementer')"

# Carve-out arms (mirrors the corrupt-state branch's carve-out): research and
# evaluation spawns, plus read-only Bash, stay unblocked so the operator can
# repair the multi-active condition without a recovery deadlock.
run_hook 0 "B11f: research Agent spawn (Explore) allowed under ≥2 active files (repair path)" \
  "$B11_AB_DIR" "$(agent_json 'search the repository' 'Explore')"
run_hook 0 "B11g: evaluation Agent spawn (autoflow-evaluator) allowed under ≥2 active files (repair path)" \
  "$B11_AB_DIR" "$(agent_json 'score this plan against the rubric' 'autoflow-evaluator')"
run_hook 0 "B11h: read-only Bash (git status) allowed under ≥2 active files" \
  "$B11_AB_DIR" "$(bash_json 'git status')"

# Asymmetric-boundary arm (feature-design F2: mirrors the CORRUPT-STATE
# carve-out, not the normal single-active role gate — analysis is exempted
# at the normal gate but NOT here): analysis, planning, testing, and an
# undeclared spawn all fail closed under ≥2 active files.
run_hook_stderr 2 "multiple active" \
  "B11i: analysis Agent spawn (autoflow-analyzer) blocked under ≥2 active files (stricter than normal single-active gate)" \
  "$B11_AB_DIR" "$(agent_json 'analyze the issue structure' 'autoflow-analyzer')"
run_hook_stderr 2 "multiple active" \
  "B11j: planning Agent spawn (autoflow-planner) blocked under ≥2 active files" \
  "$B11_AB_DIR" "$(agent_json 'plan the design approach' 'autoflow-planner')"
run_hook_stderr 2 "multiple active" \
  "B11k: testing Agent spawn (autoflow-tester) blocked under ≥2 active files" \
  "$B11_AB_DIR" "$(agent_json 'write the failing tests' 'autoflow-tester')"
run_hook_stderr 2 "multiple active" \
  "B11l: undeclared Agent spawn (unknown subagent_type, no name prefix) blocked under ≥2 active files" \
  "$B11_AB_DIR" "$(agent_json 'do something' 'SomeUnknownType')"

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $((PASS + FAIL)) total, $PASS passed, $FAIL failed"
echo "=============================="
[[ $FAIL -eq 0 ]]
