#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/hooks/check-autoflow-gate.sh
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# Test: check-autoflow-gate.sh STATE-FILE COLLECTION SCOPE (issue #64)
#
# The hook's state-file discovery previously read EVERY .autoflow/*.json as a
# state-file candidate, so a non-state JSON (e.g. the VALIDATE launch record
# issue-{N}-runtime-launch.json, #62) failed the state schema, was classified
# MALFORMED_STATE, and — once no active state file remained at cycle end —
# fail-closed blocked push-class commands. #64 restricts collection to the
# documented state-file naming rule: issue-<digits>.json (CLAUDE.md >
# AutoFlow State Tracking).
#
# Regression cases (issue #64 Scope item 2):
#   (a) non-conforming JSON only (launch-record shape) + no active state
#       → push-class commands ALLOWED (was blocked — the RED discriminator)
#   (b) a corrupt issue-<digits>.json itself → still BLOCKED (fail-closed
#       preserved, #241/#245 lineage)
#   (c) existing defenses unchanged: #245 closed-world schema rejection and
#       #843 multiple-active rejection

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$PROJECT_ROOT/.claude/hooks/check-autoflow-gate.sh"

PASS=0
FAIL=0

PUSH_JSON='{"tool_name":"Bash","tool_input":{"command":"git push origin dev"}}'

# run_hook <expected_exit> <desc> <project_dir>
run_hook() {
  local expected="$1" desc="$2" pdir="$3" actual
  actual=$(printf '%s' "$PUSH_JSON" | CLAUDE_PROJECT_DIR="$pdir" bash "$HOOK" >/dev/null 2>&1; echo $?)
  if [ "$actual" = "$expected" ]; then
    echo "  PASS: $desc (exit $actual)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected exit $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== issue #64 — state-file collection scope ==="

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/.autoflow"

# --- (a) non-conforming JSON only + no active state → allowed -------------
printf '{"head_sha":"abc","script_sha256":"def","status":"ok"}' \
  > "$TMP/.autoflow/issue-62-runtime-launch.json"
run_hook 0 "(a) launch-record-shaped JSON only, no active state → push allowed" "$TMP"

# Non-conforming names beyond the launch record: no digits-only stem.
printf 'not json at all' > "$TMP/.autoflow/cycle-digest.json"
printf 'not json at all' > "$TMP/.autoflow/issue-.json"
printf 'not json at all' > "$TMP/.autoflow/issue-12a.json"
run_hook 0 "(a2) assorted non-conforming .autoflow/*.json names → still allowed" "$TMP"
rm -f "$TMP/.autoflow/cycle-digest.json" "$TMP/.autoflow/issue-.json" "$TMP/.autoflow/issue-12a.json"

# --- (b) corrupt conforming state file → still blocked --------------------
printf 'not json {{{' > "$TMP/.autoflow/issue-9.json"
run_hook 2 "(b) corrupt issue-<digits>.json → push blocked (fail-closed preserved)" "$TMP"
rm -f "$TMP/.autoflow/issue-9.json"

# --- (c) existing defenses unchanged --------------------------------------
# (c1) #245 closed-world: schema-violating active state under a conforming name
printf '{"active":true,"bogus_key":1,"phases":{}}' > "$TMP/.autoflow/issue-3.json"
run_hook 2 "(c1) schema-violating active issue-<digits>.json → blocked (#245 closed-world unchanged)" "$TMP"
rm -f "$TMP/.autoflow/issue-3.json"

# (c2) #843 multiple-active rejection
printf '{"active":true,"phases":{}}' > "$TMP/.autoflow/issue-1.json"
printf '{"active":true,"phases":{}}' > "$TMP/.autoflow/issue-2.json"
run_hook 2 "(c2) two simultaneously-active state files → blocked (#843 unchanged)" "$TMP"
rm -f "$TMP/.autoflow/issue-1.json" "$TMP/.autoflow/issue-2.json"

echo ""
echo "=============================="
echo "Results: $((PASS + FAIL)) total, $PASS passed, $FAIL failed"
echo "=============================="

[ "$FAIL" -eq 0 ]
