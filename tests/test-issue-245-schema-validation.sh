#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: check-autoflow-gate.sh SCHEMA VALIDATION (issue #245)
# =============================================================================
# Verifies the comprehensive whole-document schema validation that closes the
# corrupt-but-valid-JSON fail-open class (R3).
#
# New fail-open cases (schema-deviation class) FAIL on the unmodified hook —
# that is the Red proof. Score-incomplete, no-deadlock, and regression cases
# pass on the unmodified hook. The AC-5 static proxy (AUTOFLOW-SCHEMA-VALIDATION
# label count == 1) also fails on the unmodified hook.
#
# AC coverage:
#   AC1  — whole-doc validation once (static: no-re-read + A8 label/exit-2-site)
#   AC2  — schema deviation → exit 2 (gated) + MALFORMED reason
#   AC3  — non-gated commands unblocked on schema-deviant state (no deadlock)
#   AC4  — item coverage: active, phases, gated-phase, scores, score-value, nested-cycle
#   AC5  — regression baseline preserved; A8 static consolidation proxy
#   AC-S — AC-7: gated-key literal in hook == gate-schema.json:gated_phase_keys
#   AC8  — reason-oracle partition: MALFORMED vs evaluation-not-run
#   AC-L1 — dual-bash matrix (bash 3.2 + 5; run script reports single-bash results;
#            caller re-runs on /opt/homebrew/bin/bash)
#   AC-L2 — no mapfile/readarray in this file (portability)
#   AC-L3 — TOCTOU single-read invariant (static grep stays 0)
#
# Placement per verification design §5/§8:
#   - Behavioral fail-closed + no-deadlock cases → this file (new)
#   - AC-7 static parity (gated-key literal == gate-schema.json) → this file
#   - A8 static proxy (label count + exit-2-site count) → this file
#   - Regression baseline is confirmed by the caller running both existing suites
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$PROJECT_ROOT/.claude/hooks/check-autoflow-gate.sh"
SCHEMA="$PROJECT_ROOT/tests/fixtures/gate-schema.json"

PASS=0
FAIL=0

# ---------------------------------------------------------------------------
# Helpers — same contract as test-gate-hardening.sh and test-issue-223-schema-hook-contract.sh
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
  # Carries an explicit model so these schema-validation cases are unaffected
  # by the Section-1b model-declaration deny (issue #475) — that deny has its
  # own coverage in test-gate-hardening.sh.
  local subtype="$1" prompt="$2"
  printf '{"tool_name":"Agent","tool_input":{"subagent_type":%s,"prompt":%s,"model":"sonnet"}}' \
    "$(printf '%s' "$subtype" | jq -Rs .)" \
    "$(printf '%s' "$prompt" | jq -Rs .)"
}
write_json() {
  # write_json <file_path> <content> — simulates a Write tool call
  printf '{"tool_name":"Write","tool_input":{"file_path":%s,"content":%s}}' \
    "$(printf '%s' "$1" | jq -Rs .)" \
    "$(printf '%s' "$2" | jq -Rs .)"
}
edit_json() {
  # edit_json <file_path> — simulates an Edit tool call (content omitted; only tool_name matters for the hook)
  printf '{"tool_name":"Edit","tool_input":{"file_path":%s,"old_string":"x","new_string":"y"}}' \
    "$(printf '%s' "$1" | jq -Rs .)"
}

# assert_static <desc> <test_command...>
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
# Single work-root for all staged fixtures (subshell-proof; single trap cleans all).
# Pattern mirrors test-issue-223-schema-hook-contract.sh:312-323.
# ---------------------------------------------------------------------------
WORKROOT="$(mktemp -d)" || { echo "mktemp failed (WORKROOT)" >&2; exit 1; }
trap 'rm -rf "$WORKROOT"' EXIT

stage_fixture() {
  # stage_fixture <json_content> → prints the project_dir path
  local content="$1"
  local d
  d="$(mktemp -d -p "$WORKROOT")" || { echo "mktemp -d -p failed in stage_fixture" >&2; return 1; }
  mkdir -p "$d/.autoflow"
  printf '%s' "$content" > "$d/.autoflow/issue-245.json"
  echo "$d"
}

# ---------------------------------------------------------------------------
# Pre-flight: schema fixture must exist
# ---------------------------------------------------------------------------
echo "=== Pre-flight: canonical source files ==="
if [[ ! -f "$SCHEMA" ]]; then
  echo "  FAIL: tests/fixtures/gate-schema.json not found"
  FAIL=$((FAIL + 1))
  echo ""
  echo "=============================="
  echo "Results: $((PASS + FAIL)) total, $PASS passed, $FAIL failed"
  echo "=============================="
  exit 1
fi
echo "  PASS: gate-schema.json present"
PASS=$((PASS + 1))

# Load schema-derived values — single source, never hardcoded below.
# bash-3.2-portable array read (no mapfile/readarray — macOS default bash is 3.2; #190).
GATED_KEYS=()
while IFS= read -r line; do GATED_KEYS+=("$line"); done < <(jq -r '.gated_phase_keys[]' "$SCHEMA")

# ============================================================================
# CLASS A — Static contract assertions (AC1, AC5, AC-S/AC-7, AC-L2, AC-L3)
# ============================================================================

echo ""
echo "=== CLASS A: Static assertions ==="

# ---
# A8 — Consolidation proxy (AC1/AC5, DCR-1 RESOLVED)
#   (a) Exactly ONE occurrence of the AUTOFLOW-SCHEMA-VALIDATION label.
#       The validation lives in ONE place, not N per-site copies.
#       On the unmodified hook this is 0 → FAIL (RED-confirming).
#   (b) Anchored `exit 2` statement count == 8. Drift history of this frozen
#       baseline: 6 at the #245 GREEN (which reused the MALFORMED_STATE block,
#       adding zero new sites) → 7 when the blocked-by-review label deny was
#       added WITHOUT bumping this baseline (latent drift: the assertion was
#       failing on main, masked because this suite is not run as a PR gate) →
#       8 with the #475 Section-1b spawn-model deny, which also repairs the
#       baseline to the actual count → 9 with the declared-spawn-role deny
#       (undeclared Agent spawn during an active cycle, replacing prompt-keyword
#       classification) → 10 with the multi-active deny (issue #843: fail
#       closed for score-gated commands/spawns when ≥2 state files read
#       active:true — feature-design F2 Change 2). Naive grep -c 'exit 2' is
#       higher (it
#       includes comment-prose mentions); the ANCHORED pattern
#       ^[[:space:]]*exit 2[[:space:]]*$ counts real statements only.
# ---
echo ""
echo "A8 — consolidation proxy (AC1/AC5)"

LABEL_COUNT=$(grep -c 'AUTOFLOW-SCHEMA-VALIDATION' "$HOOK" 2>/dev/null || true)
assert_eq "A8a: exactly ONE AUTOFLOW-SCHEMA-VALIDATION label in hook (consolidation invariant)" \
  "$LABEL_COUNT" "1"
  # ^^^ FAILS on unmodified hook (count=0) — RED-confirming

EXIT2_COUNT=$(grep -cE '^[[:space:]]*exit 2[[:space:]]*$' "$HOOK" 2>/dev/null || true)
assert_eq "A8b: anchored 'exit 2' statement count == 10 (9 prior baseline + issue #843 multi-active deny)" \
  "$EXIT2_COUNT" "10"
  # See the drift history in the A8 comment block above; bump this count (and
  # the history) whenever a deny site is intentionally added or removed.

# Confirm the naive count is NOT used (this is a documentation assertion only —
# if naive==8 and anchored==6, the discrepancy confirms 2 comment-prose mentions exist).
NAIVE_COUNT=$(grep -cE 'exit 2' "$HOOK" 2>/dev/null || true)
assert_static "A8c: naive 'exit 2' count >= anchored count (confirms comment prose not counted by anchored pattern)" \
  bash -c "[[ $NAIVE_COUNT -ge $EXIT2_COUNT ]]"

# ---
# A7 — Gated-key literal parity (AC-S/DCR-6 Option 2 + parity for gated-key literal)
#   The hook's in-filter gated-key list ["gate_hypothesis_cause","gate_plan","audit","gate_quality"]
#   must equal gate-schema.json:gated_phase_keys — single source of truth.
#   On the unmodified hook the filter does NOT exist yet → FAIL (RED-confirming).
# ---
echo ""
echo "A7 — gated-key literal parity (hook in-filter == gate-schema.json:gated_phase_keys)"

# Build the expected literal from gate-schema.json (no hardcoding).
# The filter format is ["key1","key2","key3","key4"] — a jq array literal.
SCHEMA_KEYS_LITERAL=$(jq -r '[.gated_phase_keys[]] | @json' "$SCHEMA")
# Extract the equivalent from the hook: find the quoted gated-key array in the jq filter.
# Pattern: ["gate_hypothesis_cause","gate_plan","audit","gate_quality"] — any whitespace inside.
HOOK_KEYS_LITERAL=$(grep -oE '\["gate_hypothesis_cause"[^]]*\]' "$HOOK" 2>/dev/null | head -1 | tr -d ' \t' || true)

assert_eq "A7: hook in-filter gated-key literal equals gate-schema.json:gated_phase_keys (as JSON array)" \
  "$HOOK_KEYS_LITERAL" "$SCHEMA_KEYS_LITERAL"
  # ^^^ FAILS on unmodified hook (filter not present yet) — RED-confirming

# ---
# AC-L2 — No mapfile/readarray in this test file (bash-3.2 portability)
# Asserted statically by checking this file itself.
# ---
echo ""
echo "AC-L2 — bash-3.2 portability: no actual mapfile/readarray invocations in this test file"

# The hook and test must not USE mapfile/readarray as shell built-ins (#190 portability).
# We check the hook here; the test file's own portability is confirmed by the dual-bash
# execution matrix (this file runs on /bin/bash 3.2 — any 4+ construct would fail there).
# Checking the hook: filter out comment lines (# ...) before searching.
_HOOK_NONCOMMENT=$(grep -v '^[[:space:]]*#' "$HOOK")
if echo "$_HOOK_NONCOMMENT" | grep -qE '\bmapfile\b|\breadarray\b'; then
  echo "  FAIL: AC-L2: hook contains mapfile or readarray in non-comment code (bash-3.2 portability)"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: AC-L2: hook has no mapfile/readarray in non-comment code (bash-3.2 portable)"
  PASS=$((PASS + 1))
fi

# ---
# AC-L3 — TOCTOU single-read invariant: no second jq re-read of \$STATE_FILE
# (The existing test-gate-hardening.sh:191-198 already asserts this; we re-assert
# here to confirm GREEN does not introduce a second read.)
# ---
echo ""
echo "AC-L3 — TOCTOU single-read invariant preserved"

REREAD_COUNT=$(grep -cE 'jq[^|]*"\$STATE_FILE"' "$HOOK" 2>/dev/null || true)
assert_eq "AC-L3: hook performs no jq re-read of \$STATE_FILE (single STATE_JSON snapshot)" \
  "${REREAD_COUNT:-0}" "0"

# ---
# A9 — closed-world single-source parity (issue #245 cycle 2)
#   The hook validator's closed-world literals MUST equal gate-schema.json's declared
#   vocabulary (verdict_enum, top_level_keys, cycle_key_grammar, score_range) — drift
#   detection makes the schema the single source. On the cycle-1 (open-world) hook the
#   verdict-enum and top-level-key-whitelist literals do NOT exist yet → FAIL (RED-confirming).
# ---
echo ""
echo "A9 — closed-world single-source parity (hook literals == gate-schema.json)"

# A9a: every verdict_enum member appears as a quoted string literal in the hook.
_A9_VE_MISSING=0
while IFS= read -r _v; do
  grep -qF "\"$_v\"" "$HOOK" || _A9_VE_MISSING=1
done < <(jq -r '.verdict_enum[]' "$SCHEMA")
assert_static "A9a: hook contains every gate-schema.json verdict_enum member as a literal (verdict closed to enum)" \
  bash -c "[[ $_A9_VE_MISSING -eq 0 ]]"
  # ^^^ FAILS on cycle-1 hook (enum literals absent) — RED-confirming

# A9b: hook top-level-key whitelist literal equals gate-schema.json:top_level_keys (no hardcoding).
SCHEMA_TLK_LITERAL=$(jq -r '[.top_level_keys[]] | @json' "$SCHEMA")
HOOK_TLK_LITERAL=$(grep -oE 'keys_unsorted - \[[^]]*\]' "$HOOK" 2>/dev/null | head -1 | sed -E 's/keys_unsorted - //' | tr -d ' \t' || true)
assert_eq "A9b: hook top-level-key whitelist equals gate-schema.json:top_level_keys (reject-all-unknown primitive present)" \
  "$HOOK_TLK_LITERAL" "$SCHEMA_TLK_LITERAL"
  # ^^^ FAILS on cycle-1 hook (no keys_unsorted whitelist) — RED-confirming

# A9c: hook contains the cycle_key_grammar regex literal from gate-schema.json.
A9_CYCLE_GRAMMAR=$(jq -r '.cycle_key_grammar' "$SCHEMA")
assert_static "A9c: hook contains gate-schema.json:cycle_key_grammar regex literal" \
  grep -qF "$A9_CYCLE_GRAMMAR" "$HOOK"

# A9d: hook is_score range matches gate-schema.json:score_range [min,max].
A9_SR_MIN=$(jq -r '.score_range.min' "$SCHEMA")
A9_SR_MAX=$(jq -r '.score_range.max' "$SCHEMA")
assert_static "A9d: hook is_score range matches gate-schema.json:score_range bounds" \
  grep -qE "\. >= $A9_SR_MIN and \. <= $A9_SR_MAX" "$HOOK"

# ============================================================================
# CLASS B — Behavioral assertions
# ============================================================================

echo ""
echo "=== CLASS B: Behavioral assertions ==="

# ============================================================================
# B-POSITIVE: Positive controls (schema-valid states → gated commands allowed)
# ============================================================================

echo ""
echo "B-POSITIVE: positive controls (valid states → allowed)"

# Positive: active:true boolean (not string) passes
POS_ACTIVE_DIR=$(stage_fixture '{"active":true,"issue":"#245","phases":{"audit":{"scores":{"a":{"score":8},"b":{"score":8}}},"gate_quality":{"scores":{"a":{"score":8},"b":{"score":8}}}}}')
run_hook 0 "B-POS1: active:true (boolean) + passing scores → git push allowed" \
  "$POS_ACTIVE_DIR" "$(bash_json 'git push origin dev/245')"

# Positive: active:false stays inactive (no gate)
POS_INACTIVE_DIR=$(stage_fixture '{"active":false,"issue":"#245","phases":{}}')
run_hook 0 "B-POS2: active:false → no gating (exit 0)" \
  "$POS_INACTIVE_DIR" "$(bash_json 'git push origin dev/245')"

# Positive: bare-number score form PASSES (confirmed by existing B5; re-assert here)
POS_BARENUM_DIR=$(stage_fixture '{"active":true,"issue":"#245","phases":{"audit":{"scores":{"a":8,"b":8}},"gate_quality":{"scores":{"a":8,"b":8}}}}')
run_hook 0 "B-POS3: bare-number score form (not {score:N}) → passes validator (DCR-3)" \
  "$POS_BARENUM_DIR" "$(bash_json 'git push origin dev/245')"

# Positive: valid nested fix_regression cycle → PASS (proves no over-block)
POS_NESTED_DIR=$(stage_fixture '{"active":true,"issue":"#245","phases":{"audit":{"scores":{"a":{"score":8}}},"gate_quality":{"scores":{"a":{"score":8}}}},"fix_regression":{"phases":{"audit":{"scores":{"a":{"score":8}}},"gate_quality":{"scores":{"a":{"score":8}}}}}}')
run_hook 0 "B-POS4: valid nested fix_regression cycle → git push allowed (no over-block)" \
  "$POS_NESTED_DIR" "$(bash_json 'git push origin dev/245')"

# Positive: {score:number} form passes
POS_SCOREOBJ_DIR=$(stage_fixture '{"active":true,"issue":"#245","phases":{"audit":{"scores":{"a":{"score":8}}},"gate_quality":{"scores":{"a":{"score":8}}}}}')
run_hook 0 "B-POS5: {score:N} object score form → passes validator" \
  "$POS_SCOREOBJ_DIR" "$(bash_json 'git push origin dev/245')"

# ============================================================================
# B-SCHEMA-DEVIATION: Schema-deviation class → MALFORMED reason (AC2/AC4/AC8)
#   These are the FAIL-OPEN vectors. All must exit 2 on the patched hook.
#   On the unmodified hook, the active:* deviation cases exit 0 (RED-confirming).
#   The reason-oracle is "malformed AutoFlow state file" (generic MALFORMED msg).
# ============================================================================

echo ""
echo "B-SCHEMA-DEVIATION: schema deviations → exit 2 + MALFORMED reason (AC2/AC4/AC8)"
echo "  (active:* deviations FAIL on unmodified hook — Red proof)"

# ===
# AC4 item 2 / AC2: .active non-boolean forms — THE PRIMARY FAIL-OPEN CLASS
# ===

echo ""
echo "  B2.1 — active:\"true\" (string) — the #245 gap (currently fail-open)"

# active:"true" string + git push → exit 2 [FAILS on unmodified hook]
ACT_STR_DIR=$(stage_fixture '{"active":"true","issue":"#245","phases":{"audit":{"scores":{}},"gate_quality":{"scores":{}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "B2.1a: active:\"true\" (string) + git push → exit 2, MALFORMED reason [RED-confirming]" \
  "$ACT_STR_DIR" "$(bash_json 'git push origin dev/245')"

run_hook_stderr 2 "malformed AutoFlow state file" \
  "B2.1b: active:\"true\" (string) + gh pr create → exit 2, MALFORMED reason [RED-confirming]" \
  "$ACT_STR_DIR" "$(bash_json 'gh pr create -t t -b b')"

run_hook_stderr 2 "malformed AutoFlow state file" \
  "B2.1c: active:\"true\" (string) + implementation Agent → exit 2, MALFORMED reason [RED-confirming]" \
  "$ACT_STR_DIR" "$(agent_json 'autoflow-implementer' 'implement the fix and commit')"

echo ""
echo "  B2.2 — active:1 (integer) [RED-confirming]"

ACT_INT_DIR=$(stage_fixture '{"active":1,"issue":"#245","phases":{"audit":{"scores":{}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "B2.2: active:1 (integer) + git push → exit 2, MALFORMED reason [RED-confirming]" \
  "$ACT_INT_DIR" "$(bash_json 'git push origin dev/245')"

echo ""
echo "  B2.3 — active missing (absent) [RED-confirming]"

ACT_MISSING_DIR=$(stage_fixture '{"issue":"#245","phases":{"audit":{"scores":{}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "B2.3: active key absent + git push → exit 2, MALFORMED reason [RED-confirming]" \
  "$ACT_MISSING_DIR" "$(bash_json 'git push origin dev/245')"

echo ""
echo "  B2.4 — active:null [RED-confirming]"

ACT_NULL_DIR=$(stage_fixture '{"active":null,"issue":"#245","phases":{"audit":{"scores":{}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "B2.4: active:null + git push → exit 2, MALFORMED reason [RED-confirming]" \
  "$ACT_NULL_DIR" "$(bash_json 'git push origin dev/245')"

echo ""
echo "  B2.5 — active:[] (array) [RED-confirming]"

ACT_ARR_DIR=$(stage_fixture '{"active":[],"issue":"#245","phases":{"audit":{"scores":{}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "B2.5: active:[] (array) + git push → exit 2, MALFORMED reason [RED-confirming]" \
  "$ACT_ARR_DIR" "$(bash_json 'git push origin dev/245')"

echo ""
echo "  B2.6 — active:\"false\" (string, not boolean false) [RED-confirming]"
# Note: "false" string does NOT equal boolean false — must be caught as schema-deviant.
# On current hook: .[0].active == true → false → "inactive" → exit 0 (fail-open for active issues).
# This is subtler: an operator who wrote "false" as string would think the issue is inactive
# but the hook currently admits it silently.

ACT_STRFALSE_DIR=$(stage_fixture '{"active":"false","issue":"#245","phases":{"audit":{"scores":{}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "B2.6: active:\"false\" (string) + git push → exit 2, MALFORMED reason [RED-confirming]" \
  "$ACT_STRFALSE_DIR" "$(bash_json 'git push origin dev/245')"

# ===
# AC4 item 3: phases non-object when active:true (extends SCHEMA_CORRUPT)
# ===

echo ""
echo "  B3.1 — phases:number (active:true) — structural deviation"
echo "  (Currently exit 2 via downstream score-guard; GREEN changes reason to MALFORMED)"

# phases is a number (not covered by SCHEMA_CORRUPT which uses string; new coverage)
# On unmodified hook: exit 2 via block_with_scores "not evaluable"; GREEN → MALFORMED reason.
# run_hook_stderr asserts BOTH exit 2 AND the MALFORMED reason; FAIL until GREEN.
PH_NUM_DIR=$(stage_fixture '{"active":true,"issue":"#245","phases":42}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "B3.1: active:true, phases:42 (number) + git push → exit 2, MALFORMED reason (reason changes in GREEN)" \
  "$PH_NUM_DIR" "$(bash_json 'git push origin dev/245')"

echo ""
echo "  B3.2 — phases:[] (array, active:true)"
echo "  (Currently exit 2 via downstream; GREEN changes reason to MALFORMED)"

PH_ARR_DIR=$(stage_fixture '{"active":true,"issue":"#245","phases":[]}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "B3.2: active:true, phases:[] (array) + git push → exit 2, MALFORMED reason (reason changes in GREEN)" \
  "$PH_ARR_DIR" "$(bash_json 'git push origin dev/245')"

# ===
# AC4 item 4: gated phase value is non-object when active:true
# ===

echo ""
echo "  B4.1 — gated phase value is a string"
echo "  (Currently exit 2 via downstream; GREEN consolidates to MALFORMED reason)"

PHASE_STR_DIR=$(stage_fixture '{"active":true,"issue":"#245","phases":{"gate_plan":"should-be-object","audit":{"scores":{}},"gate_quality":{"scores":{}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "B4.1: gate_plan:\"string\" (non-object phase value) + git push → exit 2, MALFORMED reason (reason changes in GREEN)" \
  "$PHASE_STR_DIR" "$(bash_json 'git push origin dev/245')"

echo ""
echo "  B4.2 — gated phase value is a number"

PHASE_NUM_DIR=$(stage_fixture '{"active":true,"issue":"#245","phases":{"audit":42,"gate_quality":{"scores":{}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "B4.2: audit:42 (number phase value) + git push → exit 2, MALFORMED reason (reason changes in GREEN)" \
  "$PHASE_NUM_DIR" "$(bash_json 'git push origin dev/245')"

echo ""
echo "  B4.3 — gated phase value is an array"

PHASE_ARR_DIR=$(stage_fixture '{"active":true,"issue":"#245","phases":{"gate_quality":[],"audit":{"scores":{}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "B4.3: gate_quality:[] (array phase value) + git push → exit 2, MALFORMED reason (reason changes in GREEN)" \
  "$PHASE_ARR_DIR" "$(bash_json 'git push origin dev/245')"

# ===
# AC4 item 5: scores is non-object (but gated phase is an object)
# ===

echo ""
echo "  B5.1 — scores is a string"
echo "  (Currently exit 2 via downstream; GREEN consolidates to MALFORMED reason)"

SCORES_STR_DIR=$(stage_fixture '{"active":true,"issue":"#245","phases":{"audit":{"scores":"should-be-object"},"gate_quality":{"scores":{}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "B5.1: audit.scores:\"string\" + git push → exit 2, MALFORMED reason (reason changes in GREEN)" \
  "$SCORES_STR_DIR" "$(bash_json 'git push origin dev/245')"

echo ""
echo "  B5.2 — scores is an array"

SCORES_ARR_DIR=$(stage_fixture '{"active":true,"issue":"#245","phases":{"audit":{"scores":[1,2,3]},"gate_quality":{"scores":{}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "B5.2: audit.scores:[] (array) + git push → exit 2, MALFORMED reason (reason changes in GREEN)" \
  "$SCORES_ARR_DIR" "$(bash_json 'git push origin dev/245')"

echo ""
echo "  B5.3 — scores is a number"

SCORES_NUM_DIR=$(stage_fixture '{"active":true,"issue":"#245","phases":{"audit":{"scores":99},"gate_quality":{"scores":{}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "B5.3: audit.scores:99 (number) + git push → exit 2, MALFORMED reason (reason changes in GREEN)" \
  "$SCORES_NUM_DIR" "$(bash_json 'git push origin dev/245')"

# ===
# AC4 item 6: score VALUE is not number-or-{score:number}
# Includes the numeric-string {score:"8"} which is the DCR-3 deliberate narrowing.
# ===

echo ""
echo "  B6.1 — score value is an array"
echo "  (Currently exit 2 via downstream; GREEN consolidates to MALFORMED reason)"

SCOREVAL_ARR_DIR=$(stage_fixture '{"active":true,"issue":"#245","phases":{"audit":{"scores":{"a":[1,2,3]}},"gate_quality":{"scores":{"a":{"score":8}}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "B6.1: score value is array [1,2,3] + git push → exit 2, MALFORMED reason (reason changes in GREEN)" \
  "$SCOREVAL_ARR_DIR" "$(bash_json 'git push origin dev/245')"

echo ""
echo "  B6.2 — score value is {value:8} (wrong sub-key)"
echo "  (Currently exit 2 via downstream; GREEN consolidates to MALFORMED reason)"

SCOREVAL_WRONGKEY_DIR=$(stage_fixture '{"active":true,"issue":"#245","phases":{"audit":{"scores":{"a":{"value":8}}},"gate_quality":{"scores":{"a":{"score":8}}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "B6.2: score value {value:8} (wrong sub-key, not .score) + git push → exit 2, MALFORMED reason (reason changes in GREEN)" \
  "$SCOREVAL_WRONGKEY_DIR" "$(bash_json 'git push origin dev/245')"

echo ""
# DCR-3: numeric-string score {score:"8"} is intentionally stricter than check_scores.
# check_scores uses tonumber which would coerce "8"→8 and PASS; is_score requires
# .score|type=="number" and REJECTS the string form. This is a deliberate narrowing
# so the validator only accepts the documented form (JSON number, not a number-as-string).
echo "  B6.3 — score value {score:\"8\"} numeric string — DCR-3 deliberate narrowing [RED-confirming]"
echo "  NOTE: check_scores would coerce \"8\"→8 and PASS; the validator rejects it intentionally."

SCOREVAL_NUMSTR_DIR=$(stage_fixture '{"active":true,"issue":"#245","phases":{"audit":{"scores":{"a":{"score":"8"}}},"gate_quality":{"scores":{"a":{"score":8}}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "B6.3: score {score:\"8\"} (numeric string) + git push → exit 2, MALFORMED (DCR-3 narrowing) [RED-confirming]" \
  "$SCOREVAL_NUMSTR_DIR" "$(bash_json 'git push origin dev/245')"

echo ""
echo "  B6.4 — score value is a nested object {score:{x:1}}"
echo "  (Currently exit 2 via downstream; GREEN consolidates to MALFORMED reason)"

SCOREVAL_NESTED_DIR=$(stage_fixture '{"active":true,"issue":"#245","phases":{"audit":{"scores":{"a":{"score":{"x":1}}}},"gate_quality":{"scores":{"a":{"score":8}}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "B6.4: score {score:{x:1}} (nested object .score) + git push → exit 2, MALFORMED reason (reason changes in GREEN)" \
  "$SCOREVAL_NESTED_DIR" "$(bash_json 'git push origin dev/245')"

# ===
# AC4 item 7: nested cycle object (fix_regression*) with corrupt scores
# ===

echo ""
echo "  B7.1 — nested fix_regression cycle with malformed scores"

NESTED_CORRUPT_DIR=$(stage_fixture '{"active":true,"issue":"#245","phases":{"audit":{"scores":{"a":{"score":8}}},"gate_quality":{"scores":{"a":{"score":8}}}},"fix_regression":{"phases":{"audit":{"scores":"corrupt-string"}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "B7.1: nested fix_regression cycle with corrupt scores + git push → exit 2, MALFORMED" \
  "$NESTED_CORRUPT_DIR" "$(bash_json 'git push origin dev/245')"

echo ""
echo "  B7.2 — nested fix_regression cycle with score numeric-string (DCR-3 applies to nested too)"

NESTED_NUMSTR_DIR=$(stage_fixture '{"active":true,"issue":"#245","phases":{"audit":{"scores":{"a":{"score":8}}},"gate_quality":{"scores":{"a":{"score":8}}}},"fix_regression":{"phases":{"audit":{"scores":{"a":{"score":"8"}}}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "B7.2: nested cycle score numeric-string + git push → exit 2, MALFORMED (nested walk)" \
  "$NESTED_NUMSTR_DIR" "$(bash_json 'git push origin dev/245')"

# ===
# B-GATED-CMD-MATRIX: Verify every gated command class fails closed on deviation
# (Use active:"true" string as the representative deviation fixture)
# ===

echo ""
echo "B-GATED-CMD-MATRIX: all gated command types fail-closed on schema deviation (AC2)"

ACT_STR_MATRIX_DIR=$(stage_fixture '{"active":"true","issue":"#245","phases":{"gate_hypothesis_cause":{"verdict":"pending","scores":{}},"gate_plan":{"scores":{}},"audit":{"scores":{}},"gate_quality":{"scores":{}}}}')

run_hook_stderr 2 "malformed AutoFlow state file" \
  "B-CMD1: active:\"true\" + git push → exit 2, MALFORMED [RED-confirming]" \
  "$ACT_STR_MATRIX_DIR" "$(bash_json 'git push origin dev/245')"

run_hook_stderr 2 "malformed AutoFlow state file" \
  "B-CMD2: active:\"true\" + gh pr create → exit 2, MALFORMED [RED-confirming]" \
  "$ACT_STR_MATRIX_DIR" "$(bash_json 'gh pr create -t title -b body')"

run_hook_stderr 2 "malformed AutoFlow state file" \
  "B-CMD3: active:\"true\" + implementation Agent → exit 2, MALFORMED [RED-confirming]" \
  "$ACT_STR_MATRIX_DIR" "$(agent_json 'autoflow-implementer' 'implement the fix and commit')"

run_hook_stderr 2 "malformed AutoFlow state file" \
  "B-CMD4: active:\"true\" + planning Agent (bug verdict pending) → exit 2, MALFORMED [RED-confirming]" \
  "$ACT_STR_MATRIX_DIR" "$(agent_json 'autoflow-planner' 'plan the design approach')"

# ============================================================================
# B-NO-DEADLOCK: Non-gated commands stay unblocked on schema-deviant state (AC3/DCR-2)
# Per hook design, MALFORMED_STATE branch gates only Bash(git push|gh pr create)
# and non-bypass Agent. Write/Edit/MultiEdit, read-only Bash, Explore/eval agents
# fall through to exit 0.
# ============================================================================

echo ""
echo "B-NO-DEADLOCK: non-gated commands unblocked on schema-deviant state (AC3/DCR-2)"

ACT_STR_NODEADLOCK_DIR=$(stage_fixture '{"active":"true","issue":"#245","phases":{"audit":{"scores":{}}}}')

run_hook 0 "B-ND1: schema-deviant state → git status (read-only Bash) → exit 0 (no deadlock)" \
  "$ACT_STR_NODEADLOCK_DIR" "$(bash_json 'git status')"

# Repair Write to the state file must be unblocked (DCR-2 pin)
run_hook 0 "B-ND2: schema-deviant state → Write tool (state file repair) → exit 0 (no deadlock)" \
  "$ACT_STR_NODEADLOCK_DIR" \
  "$(write_json "$ACT_STR_NODEADLOCK_DIR/.autoflow/issue-245.json" '{"active":true}')"

# Edit tool must also be unblocked
run_hook 0 "B-ND3: schema-deviant state → Edit tool (repair write) → exit 0 (no deadlock)" \
  "$ACT_STR_NODEADLOCK_DIR" \
  "$(edit_json "$ACT_STR_NODEADLOCK_DIR/.autoflow/issue-245.json")"

# Explore agent must be unblocked
run_hook 0 "B-ND4: schema-deviant state → Explore agent → exit 0 (research never gates)" \
  "$ACT_STR_NODEADLOCK_DIR" "$(agent_json 'Explore' 'search the repository')"

# Evaluation-keyword agent must be unblocked
run_hook 0 "B-ND5: schema-deviant state → evaluation agent → exit 0 (bypass)" \
  "$ACT_STR_NODEADLOCK_DIR" "$(agent_json 'autoflow-evaluator' 'score this plan against the rubric')"

# ============================================================================
# B-OVER-BLOCK-GUARD: active:false with corrupt phases must NOT over-block (DCR-7)
# The structural check on phases/scores runs ONLY on the active:true arm.
# active:false short-circuits to "inactive" → exit 0 without entering structural arm.
# ============================================================================

echo ""
echo "B-OVER-BLOCK-GUARD: active:false + corrupt phases → no over-block (DCR-7)"

# active:false + phases:"corrupt" (string) → must exit 0 (no over-block)
OB_STR_DIR=$(stage_fixture '{"active":false,"issue":"#245","phases":"corrupt-string"}')
run_hook 0 "B-OB1: active:false + phases:\"corrupt\" (string) + git push → exit 0 (no over-block)" \
  "$OB_STR_DIR" "$(bash_json 'git push origin dev/245')"

# active:false + corrupt nested cycle → must exit 0
OB_NESTED_DIR=$(stage_fixture '{"active":false,"issue":"#245","phases":{},"fix_regression":{"phases":{"audit":{"scores":"corrupt"}}}}')
run_hook 0 "B-OB2: active:false + corrupt nested cycle + git push → exit 0 (no over-block)" \
  "$OB_NESTED_DIR" "$(bash_json 'git push origin dev/245')"

# ============================================================================
# B-SCORE-INCOMPLETE: Score-incomplete but schema-VALID states (AC8 partition)
# These PASS the validator (verdict "active") but exit 2 via downstream
# block_with_scores with reason "evaluation not run" — NOT MALFORMED.
# RED MUST NOT add these to the MALFORMED-reason fixture set.
# Include ≥1 fixture per class so the partition is load-bearing.
# ============================================================================

echo ""
echo "B-SCORE-INCOMPLETE: schema-valid but score-incomplete → 'evaluation not run' reason (AC8 partition)"
echo "  NOTE: these are NOT schema-deviation fixtures; they pass the validator and hit downstream block_with_scores"

# Schema-valid: {"active":true} — no phases key at all
SI_NOPHASES_DIR=$(stage_fixture '{"active":true,"issue":"#245"}')
run_hook_stderr 2 "evaluation not run" \
  "B-SI1: {active:true} no phases key → exit 2, 'evaluation not run' reason (NOT MALFORMED)" \
  "$SI_NOPHASES_DIR" "$(bash_json 'git push origin dev/245')"

# Schema-valid: gated phase object with no scores key
SI_NOSCORES_DIR=$(stage_fixture '{"active":true,"issue":"#245","phases":{"audit":{}}}')
run_hook_stderr 2 "evaluation not run" \
  "B-SI2: audit:{} (no scores key) → exit 2, 'evaluation not run' reason (NOT MALFORMED)" \
  "$SI_NOSCORES_DIR" "$(bash_json 'git push origin dev/245')"

# Schema-valid: scores explicitly null
SI_NULLSCORES_DIR=$(stage_fixture '{"active":true,"issue":"#245","phases":{"audit":{"scores":null}}}')
run_hook_stderr 2 "evaluation not run" \
  "B-SI3: audit.scores:null → exit 2, 'evaluation not run' reason (NOT MALFORMED)" \
  "$SI_NULLSCORES_DIR" "$(bash_json 'git push origin dev/245')"

# Confirm the partition: these score-incomplete states do NOT trigger MALFORMED reason
# (We already verified the reason substring above; this is an explicit anti-oracle check
# asserting they do NOT match the MALFORMED substring. run_hook_stderr checks for presence,
# so we use a direct grep-based check here for the negative assertion.)
echo ""
echo "  B-SI-ANTICHECK: score-incomplete states must NOT produce MALFORMED reason"
SI_STDERR=$(mktemp)
printf '%s' "$(bash_json 'git push origin dev/245')" | CLAUDE_PROJECT_DIR="$SI_NOPHASES_DIR" bash "$HOOK" >/dev/null 2>"$SI_STDERR" || true
if grep -qF "malformed AutoFlow state file" "$SI_STDERR"; then
  echo "  FAIL: B-SI-ANTICHECK1: no-phases state produced MALFORMED reason (mis-oracle trap — partition broken)"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: B-SI-ANTICHECK1: no-phases state correctly does NOT produce MALFORMED reason"
  PASS=$((PASS + 1))
fi
rm -f "$SI_STDERR"

# ============================================================================
# B-NON-GATED-PHASE: Non-gated phase corruption must NOT over-block (feature design §4.4)
# A corrupt non-gated phase (e.g. "some_other_phase") cannot influence gated verdicts,
# so it must not be rejected as malformed.
# ============================================================================

echo ""
echo "B-NON-GATED-PHASE: corrupt non-gated phase does not over-block (§4.4)"

# some_other_phase is a non-object; the four gated phases have valid passing scores.
NGP_DIR=$(stage_fixture '{"active":true,"issue":"#245","phases":{"some_other_phase":"garbage","audit":{"scores":{"a":{"score":8}}},"gate_quality":{"scores":{"a":{"score":8}}}}}')
run_hook 0 "B-NGP1: corrupt non-gated phase + passing gated scores → git push allowed (no over-block)" \
  "$NGP_DIR" "$(bash_json 'git push origin dev/245')"

# ============================================================================
# B-EXIT-CODE-PRECISION: Exit code is exactly 2, not 5 or 1 (AC2)
# The distinction is load-bearing: PreToolUse only blocks on exit 2; exit 5 is non-blocking.
# ============================================================================

echo ""
echo "B-EXIT-CODE-PRECISION: blocked exit is exactly 2 (not 5/1) — PreToolUse only blocks on 2 (AC2)"

ACT_STR_PREC_DIR=$(stage_fixture '{"active":"true","issue":"#245","phases":{"audit":{"scores":{}}}}')
PREC_STDERR=$(mktemp)
PREC_EXIT=$(printf '%s' "$(bash_json 'git push origin dev/245')" | \
  CLAUDE_PROJECT_DIR="$ACT_STR_PREC_DIR" bash "$HOOK" >/dev/null 2>"$PREC_STDERR"; echo $?)
assert_eq "B-PREC1: active:\"true\" string deviation exit code is exactly 2 (not 5/1) [RED-confirming]" \
  "$PREC_EXIT" "2"
rm -f "$PREC_STDERR"

SCORES_NUM_PREC_DIR=$(stage_fixture '{"active":true,"issue":"#245","phases":{"audit":{"scores":99},"gate_quality":{"scores":{}}}}')
PREC2_EXIT=$(printf '%s' "$(bash_json 'git push origin dev/245')" | \
  CLAUDE_PROJECT_DIR="$SCORES_NUM_PREC_DIR" bash "$HOOK" >/dev/null 2>&1; echo $?)
assert_eq "B-PREC2: scores:99 (number) deviation exit code is exactly 2 (not 5)" \
  "$PREC2_EXIT" "2"

# ============================================================================
# B-VERDICT-TYPE: Fail-open A — verdict type bypass (Codex post-PR fix, issue #245)
#
# The R3 validator validates gated-phase `scores` shape but NOT the TYPE of
# `gate_hypothesis_cause.verdict`.  The downstream planning gate does:
#   jq -r '.phases.gate_hypothesis_cause.verdict // empty'
#   grep -qi "skip"
# A verdict that is an OBJECT or ARRAY whose jq -r rendering contains the
# substring "skip" bypasses Gate 1 even though the state file is schema-corrupt.
#
# After GREEN: all non-string verdict types → exit 2 + MALFORMED reason.
#
# Red-confirmation legend:
#   [FAIL-OPEN]   currently exit 0  — genuine fail-open
#   [REASON-RED]  currently exit 2 but NOT MALFORMED — reason-oracle partition fail
# ============================================================================

echo ""
echo "=== B-VERDICT-TYPE: verdict type bypass fail-open (Codex fix, issue #245) ==="
echo "  ([FAIL-OPEN] cases currently exit 0; [REASON-RED] cases exit 2 but wrong reason)"

# ---
# BVT-1: verdict is an OBJECT containing the substring "skip"
# jq -r on the object prints '{\n  "unexpected": "skip"\n}' → grep -qi "skip" matches
# → Gate 1 is bypassed → exit 0  [FAIL-OPEN on unmodified hook]
# ---
echo ""
echo "  BVT-1 — verdict:{\"unexpected\":\"skip\"} (object) — Gate 1 bypassed [FAIL-OPEN]"

BVT1_DIR=$(stage_fixture '{"active":true,"phases":{"gate_hypothesis_cause":{"verdict":{"unexpected":"skip"},"scores":{}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "BVT-1: verdict:{\"unexpected\":\"skip\"} (object) + planning Agent → exit 2, MALFORMED [RED-confirming, currently exit 0]" \
  "$BVT1_DIR" "$(agent_json 'autoflow-planner' 'plan the design approach')"

# ---
# BVT-2: verdict is an ARRAY ["skip"]
# jq -r on the array prints '[\n  "skip"\n]' → grep -qi "skip" matches
# → Gate 1 is bypassed → exit 0  [FAIL-OPEN on unmodified hook]
# ---
echo ""
echo "  BVT-2 — verdict:[\"skip\"] (array) — Gate 1 bypassed [FAIL-OPEN]"

BVT2_DIR=$(stage_fixture '{"active":true,"phases":{"gate_hypothesis_cause":{"verdict":["skip"],"scores":{}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "BVT-2: verdict:[\"skip\"] (array) + planning Agent → exit 2, MALFORMED [RED-confirming, currently exit 0]" \
  "$BVT2_DIR" "$(agent_json 'autoflow-planner' 'plan the design approach')"

# ---
# BVT-3: verdict is a NUMBER (42)
# jq -r prints "42" → grep -qi "skip" does NOT match → Gate 1 runs → exits 2
# BUT: reason is "evaluation not run" (downstream block_with_scores), NOT MALFORMED.
# After GREEN: must exit 2 with MALFORMED reason (schema deviation caught earlier).
# [REASON-RED on unmodified hook: exits 2 with wrong reason]
# ---
echo ""
echo "  BVT-3 — verdict:42 (number) — currently exits 2 but wrong reason [REASON-RED]"

BVT3_DIR=$(stage_fixture '{"active":true,"phases":{"gate_hypothesis_cause":{"verdict":42,"scores":{}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "BVT-3: verdict:42 (number) + planning Agent → exit 2, MALFORMED reason [RED-confirming: currently 'evaluation not run']" \
  "$BVT3_DIR" "$(agent_json 'autoflow-planner' 'plan the design approach')"

# ---
# BVT-4: verdict is a BOOLEAN (true)
# jq -r prints "true" → grep -qi "skip" does NOT match → Gate 1 runs → exits 2
# BUT: reason is "evaluation not run", NOT MALFORMED.
# [REASON-RED on unmodified hook]
# ---
echo ""
echo "  BVT-4 — verdict:true (bool) — currently exits 2 but wrong reason [REASON-RED]"

BVT4_DIR=$(stage_fixture '{"active":true,"phases":{"gate_hypothesis_cause":{"verdict":true,"scores":{}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "BVT-4: verdict:true (bool) + planning Agent → exit 2, MALFORMED reason [RED-confirming: currently 'evaluation not run']" \
  "$BVT4_DIR" "$(agent_json 'autoflow-planner' 'plan the design approach')"

# ---
# BVT-CTRL-1: CONTROL — verdict "skipped (feat issue)" (string) + planning Agent → MUST stay exit 0
# This is the live feat-skip path; GREEN must not break it.
# ---
echo ""
echo "  BVT-CTRL-1 — CONTROL: verdict:\"skipped (feat issue)\" (string) → exit 0 (feat-skip path)"

BVT_CTRL1_DIR=$(stage_fixture '{"active":true,"phases":{"gate_hypothesis_cause":{"verdict":"skipped (feat issue)","scores":{}}}}')
run_hook 0 \
  "BVT-CTRL-1: verdict:\"skipped (feat issue)\" (string) + planning Agent → exit 0 (feat-skip, must not break)" \
  "$BVT_CTRL1_DIR" "$(agent_json 'autoflow-planner' 'plan the design approach')"

# ---
# BVT-CTRL-2: CONTROL — verdict "pending" (string) + planning Agent + no scores
# → exit 2 with "evaluation not run" reason (downstream block_with_scores, NOT MALFORMED)
# This confirms the reason-oracle partition: string verdict "pending" is schema-valid;
# the gate fires legitimately, not because the verdict type is corrupt.
# ---
echo ""
echo "  BVT-CTRL-2 — CONTROL: verdict:\"pending\" (string) + no scores → exit 2, 'evaluation not run' (NOT MALFORMED)"

BVT_CTRL2_DIR=$(stage_fixture '{"active":true,"phases":{"gate_hypothesis_cause":{"verdict":"pending","scores":{}}}}')
run_hook_stderr 2 "evaluation not run" \
  "BVT-CTRL-2: verdict:\"pending\" (string) + planning Agent + no scores → exit 2, 'evaluation not run' (schema-valid block)" \
  "$BVT_CTRL2_DIR" "$(agent_json 'autoflow-planner' 'plan the design approach')"

# Confirm CTRL-2 does NOT produce MALFORMED reason (anti-oracle: partition boundary)
_BVT_CTRL2_STDERR=$(mktemp)
printf '%s' "$(agent_json 'autoflow-planner' 'plan the design approach')" \
  | CLAUDE_PROJECT_DIR="$BVT_CTRL2_DIR" bash "$HOOK" >/dev/null 2>"$_BVT_CTRL2_STDERR" || true
if grep -qF "malformed AutoFlow state file" "$_BVT_CTRL2_STDERR"; then
  echo "  FAIL: BVT-CTRL-2-ANTI: verdict:\"pending\" produced MALFORMED reason (partition broken — schema-valid 'pending' must not be MALFORMED)"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: BVT-CTRL-2-ANTI: verdict:\"pending\" correctly does NOT produce MALFORMED reason (partition intact)"
  PASS=$((PASS + 1))
fi
rm -f "$_BVT_CTRL2_STDERR"

# ============================================================================
# B-VERDICT-ENUM: Fail-open #5 — verdict VALUE bypass (cycle-2 closed-world)
#   The cycle-1 hook checks verdict is a *string* but never its VALUE. The downstream
#   planning gate bypasses GATE:HYPOTHESIS when the verdict contains "skip" (grep -qi
#   skip). A non-canonical string containing "skip" (e.g. "pending-but-skip-this")
#   therefore bypasses the planning gate for a BUG issue. Closed-world fix: verdict must
#   equal a gate-schema.json verdict_enum member (or be empty/absent → gate-not-triggered,
#   CLAUDE.md verdict rule); every other string → MALFORMED.
#   [FAIL-OPEN] cases currently exit 0 (bypass); [REASON-RED] currently exit 2 wrong reason.
# ============================================================================

echo ""
echo "=== B-VERDICT-ENUM: verdict value bypass fail-open #5 (cycle-2 closed-world) ==="

# BVE-1: THE BYPASS — non-canonical verdict containing "skip" on a bug issue.
echo ""
echo "  BVE-1 — verdict:\"pending-but-skip-this\" (contains skip, non-enum) — planning gate bypassed [FAIL-OPEN]"
BVE1_DIR=$(stage_fixture '{"active":true,"phases":{"gate_hypothesis_cause":{"verdict":"pending-but-skip-this","scores":{}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "BVE-1: verdict:\"pending-but-skip-this\" + planning Agent → exit 2, MALFORMED [RED-confirming: currently exit 0 BYPASS]" \
  "$BVE1_DIR" "$(agent_json 'autoflow-planner' 'plan the design approach')"

# BVE-2: bare "skip".
echo ""
echo "  BVE-2 — verdict:\"skip\" (bare, non-enum) — planning gate bypassed [FAIL-OPEN]"
BVE2_DIR=$(stage_fixture '{"active":true,"phases":{"gate_hypothesis_cause":{"verdict":"skip","scores":{}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "BVE-2: verdict:\"skip\" + planning Agent → exit 2, MALFORMED [RED-confirming: currently exit 0 BYPASS]" \
  "$BVE2_DIR" "$(agent_json 'autoflow-planner' 'plan the design approach')"

# BVE-3: skip embedded in a sentence.
echo ""
echo "  BVE-3 — verdict:\"please skip this gate\" (non-enum, contains skip) [FAIL-OPEN]"
BVE3_DIR=$(stage_fixture '{"active":true,"phases":{"gate_hypothesis_cause":{"verdict":"please skip this gate","scores":{}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "BVE-3: verdict:\"please skip this gate\" + planning Agent → exit 2, MALFORMED [RED-confirming: currently exit 0 BYPASS]" \
  "$BVE3_DIR" "$(agent_json 'autoflow-planner' 'plan the design approach')"

# BVE-4: non-enum string WITHOUT skip (typo of an enum member). Currently blocks with the
# WRONG reason ("evaluation not run"); closed-world routes it to MALFORMED.
echo ""
echo "  BVE-4 — verdict:\"evaluatedX\" (non-enum, no skip) → MALFORMED [REASON-RED: currently 'evaluation not run']"
BVE4_DIR=$(stage_fixture '{"active":true,"phases":{"gate_hypothesis_cause":{"verdict":"evaluatedX","scores":{}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "BVE-4: verdict:\"evaluatedX\" + planning Agent → exit 2, MALFORMED [RED-confirming: currently 'evaluation not run']" \
  "$BVE4_DIR" "$(agent_json 'autoflow-planner' 'plan the design approach')"

# BVE-CTRL-1: CONTROL — "evaluated" (enum member) → schema-valid; gate fires legitimately.
echo ""
echo "  BVE-CTRL-1 — CONTROL: verdict:\"evaluated\" (enum) + no scores → exit 2, 'evaluation not run' (NOT MALFORMED)"
BVE_CTRL1_DIR=$(stage_fixture '{"active":true,"phases":{"gate_hypothesis_cause":{"verdict":"evaluated","scores":{}}}}')
run_hook_stderr 2 "evaluation not run" \
  "BVE-CTRL-1: verdict:\"evaluated\" (enum) + planning Agent + no scores → exit 2, 'evaluation not run' (schema-valid block)" \
  "$BVE_CTRL1_DIR" "$(agent_json 'autoflow-planner' 'plan the design approach')"

# BVE-CTRL-2: CONTROL — empty verdict "" → gate-not-triggered (CLAUDE.md verdict rule); must STAY
# exit 0. (GATE:PLAN rec 3 + adversarial-review L25: validator must tolerate "" like null/absent.)
echo ""
echo "  BVE-CTRL-2 — CONTROL: verdict:\"\" (empty) + planning Agent → exit 0 (gate-not-triggered, must not over-block)"
BVE_CTRL2_DIR=$(stage_fixture '{"active":true,"phases":{"gate_hypothesis_cause":{"verdict":"","scores":{}}}}')
run_hook 0 \
  "BVE-CTRL-2: verdict:\"\" (empty) + planning Agent → exit 0 (empty=gate-not-triggered, CLAUDE.md verdict rule)" \
  "$BVE_CTRL2_DIR" "$(agent_json 'autoflow-planner' 'plan the design approach')"

# Confirm BVE-CTRL-2 does NOT produce MALFORMED (anti-oracle: empty verdict tolerated, not corrupt).
_BVE_CTRL2_STDERR=$(mktemp)
printf '%s' "$(agent_json 'autoflow-planner' 'plan the design approach')" \
  | CLAUDE_PROJECT_DIR="$BVE_CTRL2_DIR" bash "$HOOK" >/dev/null 2>"$_BVE_CTRL2_STDERR" || true
if grep -qF "malformed AutoFlow state file" "$_BVE_CTRL2_STDERR"; then
  echo "  FAIL: BVE-CTRL-2-ANTI: verdict:\"\" produced MALFORMED (empty must be tolerated like null/absent)"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: BVE-CTRL-2-ANTI: verdict:\"\" correctly does NOT produce MALFORMED (gate-not-triggered)"
  PASS=$((PASS + 1))
fi
rm -f "$_BVE_CTRL2_STDERR"

# ============================================================================
# B-SCORE-RANGE: Fail-open B — score out-of-range bypass (Codex post-PR fix, issue #245)
#
# `is_score` in the R3 jq validator checks `type == "number"` only, not the
# documented 10-point range.  A score of 999 satisfies is_score AND passes
# block_with_scores (999 ≥ 7, average ≥ 7.5) → git push exits 0 despite the
# schema being corrupt.
#
# Valid range (safe against all existing fixtures which use 1–10):
#   a score is valid iff it is a number in [0, 10] inclusive.
#
# After GREEN:
#   • score > 10 or score < 0 → exit 2 + MALFORMED (out-of-range = schema deviation)
#   • score in [0, 10] (boundaries included) → schema-valid; downstream logic decides pass/fail
#
# Red-confirmation legend:
#   [FAIL-OPEN]   currently exit 0  — genuine fail-open
#   [REASON-RED]  currently exit 2 but NOT MALFORMED — reason-oracle partition fail
# ============================================================================

echo ""
echo "=== B-SCORE-RANGE: score out-of-range fail-open (Codex fix, issue #245) ==="
echo "  ([FAIL-OPEN] cases currently exit 0; [REASON-RED] cases exit 2 but wrong reason)"

# ---
# BSR-1: audit + gate_quality with score item 999 (bare-number form) + git push
# is_score: 999 is a number → passes validator (no range check) → fail-open exit 0
# [FAIL-OPEN on unmodified hook]
# ---
echo ""
echo "  BSR-1 — audit + gate_quality: score item 999 (bare-number, {security:999,other:999}) [FAIL-OPEN]"

BSR1_DIR=$(stage_fixture '{"active":true,"phases":{"audit":{"scores":{"security":999,"other":999}},"gate_quality":{"scores":{"a":999,"b":999}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "BSR-1: audit+gate_quality security:999 + git push → exit 2, MALFORMED [RED-confirming, currently exit 0]" \
  "$BSR1_DIR" "$(bash_json 'git push origin dev/245')"

# ---
# BSR-2: bare-number score 999 in a single phase
# Confirms the range check fires on the bare-number form (not only {score:N} form).
# [FAIL-OPEN on unmodified hook]
# ---
echo ""
echo "  BSR-2 — bare-number score 999 in single phase (audit only) [FAIL-OPEN]"

BSR2_DIR=$(stage_fixture '{"active":true,"phases":{"audit":{"scores":{"a":999}},"gate_quality":{"scores":{"a":8}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "BSR-2: bare score 999 + git push → exit 2, MALFORMED [RED-confirming, currently exit 0]" \
  "$BSR2_DIR" "$(bash_json 'git push origin dev/245')"

# ---
# BSR-3: {score:999} object-form score
# Confirms the range check also fires on the {score:N} object form.
# [FAIL-OPEN on unmodified hook]
# ---
echo ""
echo "  BSR-3 — {score:999} object-form score [FAIL-OPEN]"

BSR3_DIR=$(stage_fixture '{"active":true,"phases":{"audit":{"scores":{"a":{"score":999}}},"gate_quality":{"scores":{"a":8}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "BSR-3: {score:999} object-form + git push → exit 2, MALFORMED [RED-confirming, currently exit 0]" \
  "$BSR3_DIR" "$(bash_json 'git push origin dev/245')"

# ---
# BSR-4: negative score -5 (bare-number form)
# Currently: exit 2 via block_with_scores ("lowest score -5 — each item must be ≥ 7")
# After GREEN: exit 2 with MALFORMED reason (out-of-range caught before downstream).
# [REASON-RED on unmodified hook: exits 2 with wrong reason]
# ---
echo ""
echo "  BSR-4 — negative score -5 (bare-number) — currently exits 2 but wrong reason [REASON-RED]"

BSR4_DIR=$(stage_fixture '{"active":true,"phases":{"audit":{"scores":{"a":-5}},"gate_quality":{"scores":{"a":8}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "BSR-4: bare score -5 + git push → exit 2, MALFORMED reason [RED-confirming: currently 'lowest score -5']" \
  "$BSR4_DIR" "$(bash_json 'git push origin dev/245')"

# ---
# BSR-5: negative score -5 ({score:-5} object form)
# Same as BSR-4 but verifies the object form too.
# [REASON-RED on unmodified hook]
# ---
echo ""
echo "  BSR-5 — negative score {score:-5} (object form) [REASON-RED]"

BSR5_DIR=$(stage_fixture '{"active":true,"phases":{"audit":{"scores":{"a":{"score":-5}}},"gate_quality":{"scores":{"a":8}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "BSR-5: {score:-5} object form + git push → exit 2, MALFORMED reason [RED-confirming: currently 'lowest score']" \
  "$BSR5_DIR" "$(bash_json 'git push origin dev/245')"

# ---
# BSR-CTRL-1: CONTROL — boundary score 10 (in-range) → schema-valid → passes gate → exit 0
# ---
echo ""
echo "  BSR-CTRL-1 — CONTROL: score 10 (upper boundary, in-range) → exit 0 (passes)"

BSR_CTRL1_DIR=$(stage_fixture '{"active":true,"phases":{"audit":{"scores":{"a":10,"b":10}},"gate_quality":{"scores":{"a":10,"b":10}}}}')
run_hook 0 \
  "BSR-CTRL-1: score 10 (boundary, in-range) + git push → exit 0 (schema-valid, gate passes)" \
  "$BSR_CTRL1_DIR" "$(bash_json 'git push origin dev/245')"

# ---
# BSR-CTRL-2: CONTROL — boundary score 0 (in-range) → schema-valid; downstream blocks (min < 7)
# reason must be "lowest score 0" (NOT MALFORMED) — confirms 0 is in-range.
# ---
echo ""
echo "  BSR-CTRL-2 — CONTROL: score 0 (lower boundary, in-range) → exit 2, 'lowest score' (NOT MALFORMED)"

BSR_CTRL2_DIR=$(stage_fixture '{"active":true,"phases":{"audit":{"scores":{"a":0,"b":0}},"gate_quality":{"scores":{"a":0,"b":0}}}}')
run_hook_stderr 2 "lowest score" \
  "BSR-CTRL-2: score 0 (boundary, in-range) + git push → exit 2, 'lowest score' reason (schema-valid, downstream block)" \
  "$BSR_CTRL2_DIR" "$(bash_json 'git push origin dev/245')"

# Confirm BSR-CTRL-2 does NOT produce MALFORMED reason (anti-oracle)
_BSR_CTRL2_STDERR=$(mktemp)
printf '%s' "$(bash_json 'git push origin dev/245')" \
  | CLAUDE_PROJECT_DIR="$BSR_CTRL2_DIR" bash "$HOOK" >/dev/null 2>"$_BSR_CTRL2_STDERR" || true
if grep -qF "malformed AutoFlow state file" "$_BSR_CTRL2_STDERR"; then
  echo "  FAIL: BSR-CTRL-2-ANTI: score 0 produced MALFORMED reason (0 is in-range, partition broken)"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: BSR-CTRL-2-ANTI: score 0 correctly does NOT produce MALFORMED reason (in-range, partition intact)"
  PASS=$((PASS + 1))
fi
rm -f "$_BSR_CTRL2_STDERR"

# ============================================================================
# B-CYCLE-LOC: Fail-open C — phases-cycle LOCATION bypass (3rd Codex finding, High)
#
# The R3 validator and check_scores both use the UNRESTRICTED recursive walk
#   [.. | objects | select(has("phases"))]
# which accepts a `phases` object ANYWHERE in the document. Because check_scores
# takes `last`, an out-of-schema subtree (e.g. under "metadata") carrying passing
# scores OVERRIDES the real failing top-level scores → push gate bypass (exit 0).
#
# The legitimate cycle locations are the document ROOT and any top-level
# `fix_regression*` key (documented nested cycles). After GREEN: a `phases` object
# anywhere else → exit 2 + MALFORMED reason.
#
# Red-confirmation legend:
#   [FAIL-OPEN]  currently exit 0 — the genuine bypass
#   [CTRL]       legitimate location — must STAY exit 0
# ============================================================================

echo ""
echo "=== B-CYCLE-LOC: phases-cycle LOCATION bypass (3rd Codex finding, High) ==="
echo "  ([FAIL-OPEN] cases currently exit 0; [CTRL] cases must STAY exit 0)"

# ---
# B-CYCLE-LOC-1: THE BYPASS. Real top-level scores FAIL (1/1); an out-of-schema
# "metadata.phases" subtree carries passing scores (8/8). The unrestricted walk +
# `last` lets the metadata subtree override → currently exit 0. After GREEN: the
# phases under "metadata" is in a disallowed location → exit 2 + MALFORMED.
# ---
echo ""
echo "  B-CYCLE-LOC-1 — metadata.phases passing-scores override of failing root [FAIL-OPEN]"

BCL1_DIR=$(stage_fixture '{"active":true,"phases":{"audit":{"scores":{"security":1,"quality":1}},"gate_quality":{"scores":{"quality":1}}},"metadata":{"phases":{"audit":{"scores":{"security":8,"quality":8}},"gate_quality":{"scores":{"quality":8}}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "B-CYCLE-LOC-1: metadata.phases override + git push → exit 2, MALFORMED [RED-confirming, currently exit 0 bypass]" \
  "$BCL1_DIR" "$(bash_json 'git push origin dev/245')"

# ---
# B-CYCLE-LOC-2: phases nested under a non-cycle key ("junk.deep.phases") at depth.
# The unrestricted walk accepts the deep phases as a cycle. After GREEN: disallowed
# location → exit 2 + MALFORMED.
# ---
echo ""
echo "  B-CYCLE-LOC-2 — junk.deep.phases nested under non-cycle key at depth [FAIL-OPEN]"

BCL2_DIR=$(stage_fixture '{"active":true,"phases":{"audit":{"scores":{"a":{"score":8}}},"gate_quality":{"scores":{"a":{"score":8}}}},"junk":{"deep":{"phases":{"audit":{"scores":{"a":{"score":8}}}}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "B-CYCLE-LOC-2: junk.deep.phases at depth + git push → exit 2, MALFORMED [RED-confirming, currently exit 0]" \
  "$BCL2_DIR" "$(bash_json 'git push origin dev/245')"

# ---
# B-CYCLE-LOC-CTRL-1: CONTROL — legit single cycle (phases only at root) → STAY exit 0.
# ---
echo ""
echo "  B-CYCLE-LOC-CTRL-1 — CONTROL: legit single root cycle → exit 0"

BCL_CTRL1_DIR=$(stage_fixture '{"active":true,"phases":{"audit":{"scores":{"a":{"score":8}}},"gate_quality":{"scores":{"a":{"score":8}}}}}')
run_hook 0 \
  "B-CYCLE-LOC-CTRL-1: legit single root cycle + git push → exit 0 (must not over-block)" \
  "$BCL_CTRL1_DIR" "$(bash_json 'git push origin dev/245')"

# ---
# B-CYCLE-LOC-CTRL-2: CONTROL — legit nested fix_regression cycle. Root scores FAIL
# (2/2) but the LAST cycle (fix_regression) PASSES (8/8). fix_regression is the
# documented last cycle with passing scores — this is the legitimate nested-cycle
# semantic and MUST keep working (check_scores `last` reads fix_regression). → exit 0.
# ---
echo ""
echo "  B-CYCLE-LOC-CTRL-2 — CONTROL: legit nested fix_regression cycle (passing LAST cycle) → exit 0"

BCL_CTRL2_DIR=$(stage_fixture '{"active":true,"phases":{"audit":{"scores":{"a":{"score":2}}},"gate_quality":{"scores":{"a":{"score":2}}}},"fix_regression":{"phases":{"audit":{"scores":{"a":{"score":8}}},"gate_quality":{"scores":{"a":{"score":8}}}}}}')
run_hook 0 \
  "B-CYCLE-LOC-CTRL-2: legit fix_regression cycle (passing last) + git push → exit 0 (legitimate nested semantic)" \
  "$BCL_CTRL2_DIR" "$(bash_json 'git push origin dev/245')"

# ---
# B-CYCLE-LOC-CTRL-3: CONTROL — fix_regression_cycle_2 key is also a legit cycle location → exit 0.
# ---
echo ""
echo "  B-CYCLE-LOC-CTRL-3 — CONTROL: fix_regression_cycle_2 key legit → exit 0"

BCL_CTRL3_DIR=$(stage_fixture '{"active":true,"phases":{"audit":{"scores":{"a":{"score":8}}},"gate_quality":{"scores":{"a":{"score":8}}}},"fix_regression_cycle_2":{"phases":{"audit":{"scores":{"a":{"score":8}}},"gate_quality":{"scores":{"a":{"score":8}}}}}}')
run_hook 0 \
  "B-CYCLE-LOC-CTRL-3: fix_regression_cycle_2 key + git push → exit 0 (legit cycle location)" \
  "$BCL_CTRL3_DIR" "$(bash_json 'git push origin dev/245')"

# ============================================================================
# B-CYCLE-GRAMMAR: Fail-open D — cycle-KEY grammar bypass (4th Codex finding, High)
#
# The prior cycle-location fix (commit 04e8c7f) collects allowed cycles via
#   to_entries[] | select(.key | startswith("fix_regression")) | .value
# The loose `startswith("fix_regression")` prefix ALSO admits undocumented keys
# such as `fix_regression_override`, `fix_regressionevil`, `fix_regression_cycle_x`.
# Such a key's `phases` carrying passing scores enters $allowed, the
# count-equality check passes (the disallowed-location guard does not fire), and
# check_scores' `last` picks it → real failing top-level scores are overridden →
# push gate bypass (exit 0).
#
# The documented cycle-key grammar is exactly: the literal `fix_regression`, or
# `fix_regression_cycle_<N>` with a numeric suffix. After GREEN: any cycle key
# outside that grammar → phases in a disallowed location → exit 2 + MALFORMED.
#
# Red-confirmation legend:
#   [FAIL-OPEN]  currently exit 0 — the genuine bypass
#   [CTRL]       legitimate cycle key — must STAY exit 0
# ============================================================================

echo ""
echo "=== B-CYCLE-GRAMMAR: cycle-KEY grammar bypass (4th Codex finding, High) ==="
echo "  ([FAIL-OPEN] cases currently exit 0; [CTRL] cases must STAY exit 0)"

# ---
# B-CYCLE-GRAMMAR-1: THE BYPASS. Real top-level scores FAIL (1/1); an undocumented
# `fix_regression_override` key (admitted by startswith) carries passing scores
# (8/8) → check_scores `last` picks it → currently exit 0. After GREEN: the key is
# outside the documented grammar → phases in a disallowed location → exit 2 MALFORMED.
# ---
echo ""
echo "  B-CYCLE-GRAMMAR-1 — fix_regression_override passing-scores override of failing root [FAIL-OPEN]"

BCG1_DIR=$(stage_fixture '{"active":true,"phases":{"audit":{"scores":{"security":1,"quality":1}},"gate_quality":{"scores":{"quality":1}}},"fix_regression_override":{"phases":{"audit":{"scores":{"security":8,"quality":8}},"gate_quality":{"scores":{"quality":8}}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "B-CYCLE-GRAMMAR-1: fix_regression_override override + git push → exit 2, MALFORMED [RED-confirming, currently exit 0 bypass]" \
  "$BCG1_DIR" "$(bash_json 'git push origin dev/245')"

# ---
# B-CYCLE-GRAMMAR-2: `fix_regressionevil` — no underscore separator after the
# `fix_regression` prefix. `startswith` admits it; the exact grammar rejects it.
# Passing phases override failing root → currently exit 0.
# ---
echo ""
echo "  B-CYCLE-GRAMMAR-2 — fix_regressionevil (no underscore separator) [FAIL-OPEN]"

BCG2_DIR=$(stage_fixture '{"active":true,"phases":{"audit":{"scores":{"security":1,"quality":1}},"gate_quality":{"scores":{"quality":1}}},"fix_regressionevil":{"phases":{"audit":{"scores":{"security":8,"quality":8}},"gate_quality":{"scores":{"quality":8}}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "B-CYCLE-GRAMMAR-2: fix_regressionevil override + git push → exit 2, MALFORMED [RED-confirming, currently exit 0]" \
  "$BCG2_DIR" "$(bash_json 'git push origin dev/245')"

# ---
# B-CYCLE-GRAMMAR-3: `fix_regression_cycle_x` — non-numeric suffix. `startswith`
# admits it; the grammar `^fix_regression_cycle_[0-9]+$` rejects the non-numeric x.
# Passing phases override failing root → currently exit 0.
# ---
echo ""
echo "  B-CYCLE-GRAMMAR-3 — fix_regression_cycle_x (non-numeric suffix) [FAIL-OPEN]"

BCG3_DIR=$(stage_fixture '{"active":true,"phases":{"audit":{"scores":{"security":1,"quality":1}},"gate_quality":{"scores":{"quality":1}}},"fix_regression_cycle_x":{"phases":{"audit":{"scores":{"security":8,"quality":8}},"gate_quality":{"scores":{"quality":8}}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "B-CYCLE-GRAMMAR-3: fix_regression_cycle_x override + git push → exit 2, MALFORMED [RED-confirming, currently exit 0]" \
  "$BCG3_DIR" "$(bash_json 'git push origin dev/245')"

# ---
# B-CYCLE-GRAMMAR-CTRL-1: CONTROL — `fix_regression` (exact literal) is a documented
# cycle key. Root scores FAIL (1/1); the fix_regression cycle PASSES (8/8) → the
# legitimate nested-cycle semantic (check_scores `last`) MUST keep working → exit 0.
# ---
echo ""
echo "  B-CYCLE-GRAMMAR-CTRL-1 — CONTROL: fix_regression (exact) passing last cycle → exit 0"

BCG_CTRL1_DIR=$(stage_fixture '{"active":true,"phases":{"audit":{"scores":{"security":1,"quality":1}},"gate_quality":{"scores":{"quality":1}}},"fix_regression":{"phases":{"audit":{"scores":{"security":8,"quality":8}},"gate_quality":{"scores":{"quality":8}}}}}')
run_hook 0 \
  "B-CYCLE-GRAMMAR-CTRL-1: fix_regression (exact) passing last cycle + git push → exit 0 (legit grammar, must not over-block)" \
  "$BCG_CTRL1_DIR" "$(bash_json 'git push origin dev/245')"

# ---
# B-CYCLE-GRAMMAR-CTRL-2: CONTROL — `fix_regression_cycle_2` matches the documented
# grammar (numeric suffix). Passing → exit 0.
# ---
echo ""
echo "  B-CYCLE-GRAMMAR-CTRL-2 — CONTROL: fix_regression_cycle_2 (numeric suffix) passing → exit 0"

BCG_CTRL2_DIR=$(stage_fixture '{"active":true,"phases":{"audit":{"scores":{"security":1,"quality":1}},"gate_quality":{"scores":{"quality":1}}},"fix_regression_cycle_2":{"phases":{"audit":{"scores":{"security":8,"quality":8}},"gate_quality":{"scores":{"quality":8}}}}}')
run_hook 0 \
  "B-CYCLE-GRAMMAR-CTRL-2: fix_regression_cycle_2 passing + git push → exit 0 (legit grammar)" \
  "$BCG_CTRL2_DIR" "$(bash_json 'git push origin dev/245')"

# ---
# B-CYCLE-GRAMMAR-CTRL-3: CONTROL — `fix_regression_cycle_10` (multi-digit suffix)
# matches `^fix_regression_cycle_[0-9]+$`. Passing → exit 0. Guards against a
# single-digit-only grammar regression.
# ---
echo ""
echo "  B-CYCLE-GRAMMAR-CTRL-3 — CONTROL: fix_regression_cycle_10 (multi-digit suffix) passing → exit 0"

BCG_CTRL3_DIR=$(stage_fixture '{"active":true,"phases":{"audit":{"scores":{"security":1,"quality":1}},"gate_quality":{"scores":{"quality":1}}},"fix_regression_cycle_10":{"phases":{"audit":{"scores":{"security":8,"quality":8}},"gate_quality":{"scores":{"quality":8}}}}}')
run_hook 0 \
  "B-CYCLE-GRAMMAR-CTRL-3: fix_regression_cycle_10 (multi-digit) passing + git push → exit 0 (legit grammar)" \
  "$BCG_CTRL3_DIR" "$(bash_json 'git push origin dev/245')"

# ============================================================================
# B-CLOSED-WORLD: Fail-open #6 — open-world top-level (cycle-2 closed-world)
#   The cycle-1 hook never whitelisted top-level keys nor type-checked non-gate fields →
#   an unknown top-level key or a wrong-typed field passes unchecked (open-world).
#   Closed-world fix: top-level keys must be in gate-schema.json top_level_keys (or match
#   cycle_key_grammar) AND each declared field must have the right type; everything else →
#   MALFORMED. The whitelist is a reject-all-unknown primitive — it structurally ends the
#   "unknown field X" finding stream (the cycle-1→2 paradigm shift).
#   [FAIL-OPEN] cases currently exit 0; [CTRL] must STAY exit 0 (no over-block).
# ============================================================================

echo ""
echo "=== B-CLOSED-WORLD: open-world top-level fail-open #6 (cycle-2 closed-world) ==="

# BCW-1: unknown scalar top-level key alongside passing scores.
echo ""
echo "  BCW-1 — unknown top-level key {\"foo\":\"bar\"} + passing scores [FAIL-OPEN]"
BCW1_DIR=$(stage_fixture '{"active":true,"foo":"bar","phases":{"audit":{"scores":{"a":8,"b":8}},"gate_quality":{"scores":{"a":8,"b":8}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "BCW-1: unknown key foo + git push → exit 2, MALFORMED [RED-confirming: currently exit 0 BYPASS]" \
  "$BCW1_DIR" "$(bash_json 'git push origin dev/245')"

# BCW-2: unknown OBJECT top-level key (no phases inside → NOT caught by the location guard).
echo ""
echo "  BCW-2 — unknown top-level object key {\"extra\":{\"k\":1}} (no phases) + passing [FAIL-OPEN]"
BCW2_DIR=$(stage_fixture '{"active":true,"extra":{"k":1},"phases":{"audit":{"scores":{"a":8,"b":8}},"gate_quality":{"scores":{"a":8,"b":8}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "BCW-2: unknown object key extra (no phases) + git push → exit 2, MALFORMED [RED-confirming: currently exit 0]" \
  "$BCW2_DIR" "$(bash_json 'git push origin dev/245')"

# BCW-3: wrong-typed top-level field cycle (array, not number).
echo ""
echo "  BCW-3 — wrong-typed top-level field cycle:[] + passing [FAIL-OPEN]"
BCW3_DIR=$(stage_fixture '{"active":true,"cycle":[],"phases":{"audit":{"scores":{"a":8,"b":8}},"gate_quality":{"scores":{"a":8,"b":8}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "BCW-3: cycle:[] (wrong type) + git push → exit 2, MALFORMED [RED-confirming: currently exit 0]" \
  "$BCW3_DIR" "$(bash_json 'git push origin dev/245')"

# BCW-4: wrong-typed top-level field mode (number, not string).
echo ""
echo "  BCW-4 — wrong-typed top-level field mode:42 + passing [FAIL-OPEN]"
BCW4_DIR=$(stage_fixture '{"active":true,"mode":42,"phases":{"audit":{"scores":{"a":8,"b":8}},"gate_quality":{"scores":{"a":8,"b":8}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "BCW-4: mode:42 (wrong type) + git push → exit 2, MALFORMED [RED-confirming: currently exit 0]" \
  "$BCW4_DIR" "$(bash_json 'git push origin dev/245')"

# BCW-5: wrong-typed top-level field issue (number, not string).
echo ""
echo "  BCW-5 — wrong-typed top-level field issue:5 + passing [FAIL-OPEN]"
BCW5_DIR=$(stage_fixture '{"active":true,"issue":5,"phases":{"audit":{"scores":{"a":8,"b":8}},"gate_quality":{"scores":{"a":8,"b":8}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "BCW-5: issue:5 (wrong type) + git push → exit 2, MALFORMED [RED-confirming: currently exit 0]" \
  "$BCW5_DIR" "$(bash_json 'git push origin dev/245')"

# BCW-6: wrong-typed top-level field phase (object, not string) — distinct from `phases`.
echo ""
echo "  BCW-6 — wrong-typed top-level field phase:{} + passing [FAIL-OPEN]"
BCW6_DIR=$(stage_fixture '{"active":true,"phase":{},"phases":{"audit":{"scores":{"a":8,"b":8}},"gate_quality":{"scores":{"a":8,"b":8}}}}')
run_hook_stderr 2 "malformed AutoFlow state file" \
  "BCW-6: phase:{} (wrong type) + git push → exit 2, MALFORMED [RED-confirming: currently exit 0]" \
  "$BCW6_DIR" "$(bash_json 'git push origin dev/245')"

# BCW-CTRL-1: CONTROL — a FULL realistic state with ALL whitelisted top-level keys and correct
# types + passing scores → exit 0. Guards the whitelist/type checks against over-blocking a real state.
echo ""
echo "  BCW-CTRL-1 — CONTROL: full realistic state (all top-level keys, correct types) + passing → exit 0"
BCW_CTRL1_DIR=$(stage_fixture '{"active":true,"issue":"#245","title":"t","date":"2026-06-01","cycle":2,"mode":"new-issue","phase":"in-progress","phases":{"gate_hypothesis_structure":{"evaluator":"x","scores":{"a":9}},"gate_hypothesis_cause":{"evaluator":"","scores":{},"verdict":"skipped (feat issue)"},"gate_plan":{"evaluator":"x","scores":{"a":9}},"audit":{"evaluator":"x","scores":{"a":9,"b":9}},"gate_quality":{"evaluator":"x","scores":{"a":9,"b":9}}}}')
run_hook 0 \
  "BCW-CTRL-1: full realistic state (all whitelisted keys + correct types) + git push → exit 0 (no over-block)" \
  "$BCW_CTRL1_DIR" "$(bash_json 'git push origin dev/245')"

# BCW-CTRL-1-ANTI: confirm the full realistic state does NOT produce MALFORMED.
_BCW_CTRL1_STDERR=$(mktemp)
printf '%s' "$(bash_json 'git push origin dev/245')" \
  | CLAUDE_PROJECT_DIR="$BCW_CTRL1_DIR" bash "$HOOK" >/dev/null 2>"$_BCW_CTRL1_STDERR" || true
if grep -qF "malformed AutoFlow state file" "$_BCW_CTRL1_STDERR"; then
  echo "  FAIL: BCW-CTRL-1-ANTI: full realistic state produced MALFORMED (whitelist/type over-block)"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: BCW-CTRL-1-ANTI: full realistic state correctly does NOT produce MALFORMED (no over-block)"
  PASS=$((PASS + 1))
fi
rm -f "$_BCW_CTRL1_STDERR"

# ============================================================================
# Results
# ============================================================================

echo ""
echo "=============================="
echo "Results: $((PASS + FAIL)) total, $PASS passed, $FAIL failed"
echo "=============================="
[[ $FAIL -eq 0 ]]
