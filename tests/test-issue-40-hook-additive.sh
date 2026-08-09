#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: issue #40 — fail_hypothesis is hook no-impact (AC3)
# =============================================================================
# Verification design: .autoflow/issue-40-verification-design.md §3 AC3, §6.
# Harness copied from tests/test-issue-245-schema-validation.sh:53
# (printf json | CLAUDE_PROJECT_DIR=$tmp bash $HOOK), per the design's own
# harness precedent citation. Fixtures are staged into a hermetic mktemp -d,
# never into the repo's live .autoflow/ (tests/test-issue-18-fixture-glob-isolation.sh
# precedent — a stray active JSON there would fail-close this very cycle's
# own gates).
#
# D1 is settled (verification design §4): fail_hypothesis recording in state
# is PERMITTED, NOT REQUIRED. Consequence, stated as the suite's own non-goal:
#   [MUST] No assertion in this suite may require fail_hypothesis to be
#   PRESENT in a state file. H-ABSENT-EQ pins the absence case as equally
#   valid; H-EQUIV is the differential oracle that keeps "permitted" from
#   hardening into "required".
#
# Every fixture below is classified a PRESERVATION GUARD (verification design
# §6): the hook already tolerates an unknown phase-object sibling key today,
# so all of H-PASS-EQ/H-FAIL-EQ/H-SEC-EQ/H-SPAWN-EQ/H-EQUIV/H-ABSENT-EQ/
# H-TOPLEVEL-NEG/H-SCORES-NEG/H-DIGEST/H-BYTES PASS now AND after GREEN. AC3's
# only RED discriminator (the State File Linkage placement sentence,
# 40-AC3-placement-rule) lives in the permanent doc-invariant registry, not
# here — this file has no discriminator by AC3's own no-impact nature.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$PROJECT_ROOT/.claude/hooks/check-autoflow-gate.sh"
EMIT_SCRIPT="$PROJECT_ROOT/scripts/handoff/emit-cycle-digest.sh"
DIGEST_SCHEMA="$PROJECT_ROOT/tests/fixtures/cycle-digest-schema.json"

PASS=0
FAIL=0

# --- Helpers (copied per tests/test-issue-245-schema-validation.sh:50-92) ---

run_hook() {                  # run_hook <expected_exit> <desc> <project_dir> <json>
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

hook_exit() {                 # hook_exit <project_dir> <json> -> exit code on stdout
  local pdir="$1" json="$2"
  printf '%s' "$json" | CLAUDE_PROJECT_DIR="$pdir" bash "$HOOK" >/dev/null 2>&1
  echo $?
}

hook_stderr() {                # hook_stderr <project_dir> <json> -> stderr on stdout
  local pdir="$1" json="$2"
  printf '%s' "$json" | CLAUDE_PROJECT_DIR="$pdir" bash "$HOOK" 2>&1 >/dev/null
}

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

bash_json()  { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(printf '%s' "$1" | jq -Rs .)"; }
agent_json() {
  local subtype="$1" prompt="$2"
  printf '{"tool_name":"Agent","tool_input":{"subagent_type":%s,"prompt":%s,"model":"sonnet"}}' \
    "$(printf '%s' "$subtype" | jq -Rs .)" \
    "$(printf '%s' "$prompt" | jq -Rs .)"
}

WORKROOT="$(mktemp -d)" || { echo "mktemp failed (WORKROOT)" >&2; exit 1; }
trap 'rm -rf "$WORKROOT"' EXIT

stage_fixture() {             # stage_fixture <json_content> -> prints project_dir
  local content="$1" d
  d="$(mktemp -d -p "$WORKROOT")" || { echo "mktemp -d -p failed" >&2; return 1; }
  mkdir -p "$d/.autoflow"
  printf '%s' "$content" > "$d/.autoflow/issue-40.json"
  echo "$d"
}

echo "=== issue #40 — fail_hypothesis hook no-impact suite (AC3) ==="

# ---------------------------------------------------------------------------
# Fixture bodies. Each has a WITH-field variant (phase-level sibling of
# `scores`, per feature design §4 [MUST]) and a WITHOUT-field variant that is
# otherwise byte-identical, so the paired comparison isolates the field alone.
# ---------------------------------------------------------------------------

PASS_WITHOUT='{"active":true,"issue":"#40","phases":{"gate_plan":{"scores":{"a":{"score":8}}},"audit":{"scores":{"a":{"score":8}}},"gate_quality":{"scores":{"a":{"score":8}}}}}'
PASS_WITH='{"active":true,"issue":"#40","phases":{"gate_plan":{"scores":{"a":{"score":8}},"fail_hypothesis":{"case":"x","disposition":"none_found","reflected_in":[]}},"audit":{"scores":{"a":{"score":8}}},"gate_quality":{"scores":{"a":{"score":8}}}}}'

FAIL_WITHOUT='{"active":true,"issue":"#40","phases":{"gate_plan":{"scores":{"a":{"score":8}}},"audit":{"scores":{"a":{"score":6}}},"gate_quality":{"scores":{"a":{"score":8}}}}}'
FAIL_WITH='{"active":true,"issue":"#40","phases":{"gate_plan":{"scores":{"a":{"score":8}}},"audit":{"scores":{"a":{"score":6}},"fail_hypothesis":{"case":"x","disposition":"survived","reflected_in":["a"]}},"gate_quality":{"scores":{"a":{"score":8}}}}}'

SEC_WITHOUT='{"active":true,"issue":"#40","phases":{"gate_plan":{"scores":{"a":{"score":8}}},"audit":{"scores":{"security":{"score":3},"other":{"score":8}}},"gate_quality":{"scores":{"a":{"score":8}}}}}'
SEC_WITH='{"active":true,"issue":"#40","phases":{"gate_plan":{"scores":{"a":{"score":8}}},"audit":{"scores":{"security":{"score":3},"other":{"score":8}},"fail_hypothesis":{"case":"x","disposition":"none_found","reflected_in":[]}},"gate_quality":{"scores":{"a":{"score":8}}}}}'

SPAWN_WITHOUT='{"active":true,"issue":"#40","phases":{"gate_plan":{"scores":{"a":{"score":8}}}}}'
SPAWN_WITH='{"active":true,"issue":"#40","phases":{"gate_plan":{"scores":{"a":{"score":8}},"fail_hypothesis":{"case":"x","disposition":"none_found","reflected_in":[]}}}}'

ABSENT_ALL='{"active":true,"issue":"#40","phases":{"gate_plan":{"scores":{"a":{"score":8}}},"audit":{"scores":{"a":{"score":8}}},"gate_quality":{"scores":{"a":{"score":8}}}}}'

TOPLEVEL_BAD='{"active":true,"issue":"#40","fail_hypothesis":{"case":"x","disposition":"none_found","reflected_in":[]},"phases":{"gate_plan":{"scores":{"a":{"score":8}}},"audit":{"scores":{"a":{"score":8}}},"gate_quality":{"scores":{"a":{"score":8}}}}}'
SCORES_BAD='{"active":true,"issue":"#40","phases":{"gate_plan":{"scores":{"a":{"score":8},"fail_hypothesis":{"case":"x"}}},"audit":{"scores":{"a":{"score":8}}},"gate_quality":{"scores":{"a":{"score":8}}}}}'

# ---------------------------------------------------------------------------
# H-PASS-EQ / H-FAIL-EQ / H-SEC-EQ / H-SPAWN-EQ — paired equality (preservation)
# ---------------------------------------------------------------------------
echo ""
echo "H-PASS-EQ / H-FAIL-EQ / H-SEC-EQ / H-SPAWN-EQ — paired with/without-field equality"

PASS_W_DIR=$(stage_fixture "$PASS_WITH"); PASS_WO_DIR=$(stage_fixture "$PASS_WITHOUT")
run_hook 0 "H-PASS-EQ: passing scores WITH fail_hypothesis + git push -> exit 0" "$PASS_W_DIR" "$(bash_json 'git push origin dev/40')"
run_hook 0 "H-PASS-EQ: passing scores WITHOUT fail_hypothesis + git push -> exit 0" "$PASS_WO_DIR" "$(bash_json 'git push origin dev/40')"

FAIL_W_DIR=$(stage_fixture "$FAIL_WITH"); FAIL_WO_DIR=$(stage_fixture "$FAIL_WITHOUT")
run_hook 2 "H-FAIL-EQ: min<7 WITH fail_hypothesis + git push -> exit 2 (field does not rescue a FAIL)" "$FAIL_W_DIR" "$(bash_json 'git push origin dev/40')"
run_hook 2 "H-FAIL-EQ: min<7 WITHOUT fail_hypothesis + git push -> exit 2" "$FAIL_WO_DIR" "$(bash_json 'git push origin dev/40')"

SEC_W_DIR=$(stage_fixture "$SEC_WITH"); SEC_WO_DIR=$(stage_fixture "$SEC_WITHOUT")
run_hook 2 "H-SEC-EQ: security<=3 WITH fail_hypothesis + gh pr create -> exit 2 (security floor unaffected)" "$SEC_W_DIR" "$(bash_json 'gh pr create -t t -b b')"
run_hook 2 "H-SEC-EQ: security<=3 WITHOUT fail_hypothesis + gh pr create -> exit 2" "$SEC_WO_DIR" "$(bash_json 'gh pr create -t t -b b')"

SPAWN_W_DIR=$(stage_fixture "$SPAWN_WITH"); SPAWN_WO_DIR=$(stage_fixture "$SPAWN_WITHOUT")
run_hook 0 "H-SPAWN-EQ: gate_plan passing WITH fail_hypothesis + implementer spawn -> exit 0" "$SPAWN_W_DIR" "$(agent_json 'autoflow-implementer' 'make the failing tests pass')"
run_hook 0 "H-SPAWN-EQ: gate_plan passing WITHOUT fail_hypothesis + implementer spawn -> exit 0" "$SPAWN_WO_DIR" "$(agent_json 'autoflow-implementer' 'make the failing tests pass')"

# ---------------------------------------------------------------------------
# H-EQUIV — differential oracle: every fixture's with/without pair produces
# the SAME exit code AND the same stderr (stronger than four fixed expectations).
# ---------------------------------------------------------------------------
echo ""
echo "H-EQUIV — differential oracle over all four fixture pairs"

check_equiv() {              # check_equiv <label> <with_dir> <without_dir> <json>
  local label="$1" wdir="$2" wodir="$3" json="$4"
  local we wo se so
  we=$(hook_exit "$wdir" "$json"); wo=$(hook_exit "$wodir" "$json")
  # Strip the "State file: <tmpdir path>" line — it necessarily differs
  # between the two hermetic mktemp fixture dirs and is not part of the
  # verdict; comparing it would false-fail every pair.
  se=$(hook_stderr "$wdir" "$json" | grep -v '^State file:')
  so=$(hook_stderr "$wodir" "$json" | grep -v '^State file:')
  if [[ "$we" == "$wo" && "$se" == "$so" ]]; then
    echo "  PASS: H-EQUIV ($label): with/without exit ($we) and stderr identical"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: H-EQUIV ($label): with=exit:$we without=exit:$wo (stderr differs: $([[ "$se" == "$so" ]] && echo no || echo yes))"
    FAIL=$((FAIL + 1))
  fi
}

check_equiv "PASS" "$PASS_W_DIR" "$PASS_WO_DIR" "$(bash_json 'git push origin dev/40')"
check_equiv "FAIL" "$FAIL_W_DIR" "$FAIL_WO_DIR" "$(bash_json 'git push origin dev/40')"
check_equiv "SEC" "$SEC_W_DIR" "$SEC_WO_DIR" "$(bash_json 'gh pr create -t t -b b')"
check_equiv "SPAWN" "$SPAWN_W_DIR" "$SPAWN_WO_DIR" "$(agent_json 'autoflow-implementer' 'make the failing tests pass')"

# ---------------------------------------------------------------------------
# H-ABSENT-EQ — omission is a fully valid state file (keeps permission from
# hardening into a requirement).
# ---------------------------------------------------------------------------
echo ""
echo "H-ABSENT-EQ — no fail_hypothesis anywhere, passing scores -> exit 0"

ABSENT_DIR=$(stage_fixture "$ABSENT_ALL")
run_hook 0 "H-ABSENT-EQ: fail_hypothesis absent everywhere, passing scores + git push -> exit 0" "$ABSENT_DIR" "$(bash_json 'git push origin dev/40')"

# ---------------------------------------------------------------------------
# H-TOPLEVEL-NEG / H-SCORES-NEG — the two forbidden placements fail closed
# (pins F1/§4's [DENY], independent of this cycle's contract text).
# ---------------------------------------------------------------------------
echo ""
echo "H-TOPLEVEL-NEG / H-SCORES-NEG — forbidden placements fail closed (MALFORMED)"

TOP_DIR=$(stage_fixture "$TOPLEVEL_BAD")
TOP_STDERR="$(hook_stderr "$TOP_DIR" "$(bash_json 'git push origin dev/40')")"
TOP_EXIT="$(hook_exit "$TOP_DIR" "$(bash_json 'git push origin dev/40')")"
assert_eq "H-TOPLEVEL-NEG: top-level fail_hypothesis + git push -> exit 2" "$TOP_EXIT" "2"
if grep -qF 'malformed' <<<"$TOP_STDERR"; then
  echo "  PASS: H-TOPLEVEL-NEG: reason mentions malformed state file"; PASS=$((PASS + 1))
else
  echo "  FAIL: H-TOPLEVEL-NEG: reason does not mention malformed state file ($TOP_STDERR)"; FAIL=$((FAIL + 1))
fi

SCORES_DIR=$(stage_fixture "$SCORES_BAD")
SCORES_EXIT="$(hook_exit "$SCORES_DIR" "$(bash_json 'git push origin dev/40')")"
SCORES_STDERR="$(hook_stderr "$SCORES_DIR" "$(bash_json 'git push origin dev/40')")"
assert_eq "H-SCORES-NEG: fail_hypothesis inside scores + git push -> exit 2" "$SCORES_EXIT" "2"
if grep -qF 'malformed' <<<"$SCORES_STDERR"; then
  echo "  PASS: H-SCORES-NEG: reason mentions malformed state file"; PASS=$((PASS + 1))
else
  echo "  FAIL: H-SCORES-NEG: reason does not mention malformed state file ($SCORES_STDERR)"; FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
# H-DIGEST — phase-level fail_hypothesis is ignored by the cycle-digest
# emitter; the emitted line still validates against the digest schema.
# Run in an isolated temp copy of the repo (tests/test-issue-953-cycle-digest.sh
# precedent) — never against the live, git-tracked docs/cycle-digest.jsonl.
# ---------------------------------------------------------------------------
echo ""
echo "H-DIGEST — phase-level fail_hypothesis is ignored by emit-cycle-digest.sh"

if [ -f "$EMIT_SCRIPT" ] && [ -f "$DIGEST_SCHEMA" ]; then
  TMP_REPO="$(mktemp -d)"
  (cd "$PROJECT_ROOT" && tar --exclude='.git' -cf - .) | (cd "$TMP_REPO" && tar -xf -) 2>/dev/null
  mkdir -p "$TMP_REPO/.autoflow" "$TMP_REPO/docs"
  : > "$TMP_REPO/docs/cycle-digest.jsonl"
  cat > "$TMP_REPO/.autoflow/issue-40.json" <<'EOF'
{ "active": true, "issue": "#40", "title": "fixture", "date": "2026-01-01", "cycle": 1, "mode": "new-issue",
  "phases": {
    "gate_hypothesis_cause": {"verdict": "skipped (feat issue)"},
    "gate_plan": {"scores": {"a": {"score": 8}}, "fail_hypothesis": {"case": "x", "disposition": "none_found", "reflected_in": []}},
    "audit": {"scores": {"a": {"score": 8}}},
    "gate_quality": {"scores": {"a": {"score": 8}}}
  }
}
EOF
  DIGEST_OUT=$( (cd "$TMP_REPO" && bash scripts/handoff/emit-cycle-digest.sh .autoflow/issue-40.json '' '' 2>&1) )
  DIGEST_EXIT=$?
  assert_eq "H-DIGEST: emit-cycle-digest.sh exits 0 against a phase-level fail_hypothesis fixture" "$DIGEST_EXIT" "0"

  DIGEST_LINE="$(tail -1 "$TMP_REPO/docs/cycle-digest.jsonl" 2>/dev/null)"
  if [ -n "$DIGEST_LINE" ] && jq -e --slurpfile schema "$DIGEST_SCHEMA" '
      ($schema[0].top_level_keys) as $tlk
      | (keys_unsorted - $tlk | length == 0)
    ' <<<"$DIGEST_LINE" >/dev/null 2>&1; then
    echo "  PASS: H-DIGEST: emitted line's top-level keys match the digest schema (no extra key from fail_hypothesis)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: H-DIGEST: emitted line missing or does not match digest schema top-level keys"
    FAIL=$((FAIL + 1))
  fi
  rm -rf "$TMP_REPO"
else
  echo "  FAIL: H-DIGEST: emit-cycle-digest.sh or cycle-digest-schema.json not found"
  FAIL=$((FAIL + 1))
fi

# H-BYTES (retired, #64): the "hook byte-unchanged vs base" fence was a #40
# cycle-scope seal; it blocked every legitimate later hook change (change-
# detector anti-pattern) and was removed in the #64 hook-fix PR.

echo ""
echo "=============================="
echo "Results: $((PASS + FAIL)) total, $PASS passed, $FAIL failed"
echo "=============================="
[[ $FAIL -eq 0 ]]
