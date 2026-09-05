#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/preflight/local-checks.sh setup/manifest.json docs/autoflow-guide.md
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: PREFLIGHT target-declared local checks call site — Issue #181
# =============================================================================
# Scope (issue #181 requirements 1–3): scripts/preflight/local-checks.sh reads
# `preflight.local_checks[]` from .claude/autoflow.local.json, runs each
# declared `check` (repair-then-recheck when `repair` is declared), stops
# fail-closed on a failure, is a recorded no-op with nothing declared, knows
# no specific tool, and writes its outcome as a ledger record — never to the
# state file. The script ships in the thin-root bundle and the PREFLIGHT
# playbook names it as a stop condition.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PROJECT_ROOT/scripts/preflight/local-checks.sh"
MANIFEST="$PROJECT_ROOT/setup/manifest.json"
GUIDE_MD="$PROJECT_ROOT/docs/autoflow-guide.md"
LEDGER_ID="$PROJECT_ROOT/scripts/ledger/ledger-entry-id.sh"

PASS=0; FAIL=0; TESTS=0
assert_true() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if eval "$condition"; then
    echo "  PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/.claude"
CFG="$WORK/.claude/autoflow.local.json"
LEDGER="$WORK/.autoflow/issue-1-ledger.md"

run() {  # run <log-name> [args...] → sets RC
  local log="$1"; shift
  ( "$SCRIPT" --root "$WORK" --config "$CFG" --ledger "$LEDGER" --cycle 2 "$@" ) >"$WORK/$log.log" 2>&1
  RC=$?
}

echo "=============================================="
echo "PREFLIGHT target-declared local checks (issue #181)"
echo "=============================================="

assert_true "script exists and is executable" "[ -x '$SCRIPT' ]"

echo "=== requirement 2: no declaration → no-op, recorded ==="
rm -f "$CFG"
run r2-absent-file
assert_true "absent config file: exit 0" "[ '$RC' -eq 0 ]"
assert_true "absent config file: prints 'PREFLIGHT local checks: none declared'" \
  "grep -q 'PREFLIGHT local checks: none declared' '$WORK/r2-absent-file.log'"
assert_true "absent config file: ledger carries the record" \
  "grep -q '^### preflight-local-checks | cycle: 2' '$LEDGER' && grep -q -- '- result: PREFLIGHT local checks: none declared' '$LEDGER'"

echo '{ "review": { "backend": "codex" } }' > "$CFG"
run r2-absent-key
assert_true "config without .preflight (the shipped scaffold): exit 0 + none declared" \
  "[ '$RC' -eq 0 ] && grep -q 'none declared' '$WORK/r2-absent-key.log'"

echo '{ "preflight": { "local_checks": [] } }' > "$CFG"
run r2-empty
assert_true "empty local_checks[]: exit 0 + none declared" \
  "[ '$RC' -eq 0 ] && grep -q 'none declared' '$WORK/r2-empty.log'"

echo "=== requirement 1: declared checks run; fail-closed; repair then recheck ==="
# A stateful fake tool: `--check` passes iff a marker file exists; `--install`
# creates it. The framework must not know the tool — only its exit status.
cat > "$WORK/tool.sh" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  --check)   if [ -f "$MARKER" ]; then echo WIRED; exit 0; else echo UNWIRED; exit 1; fi ;;
  --install) touch "$MARKER"; echo installed; exit 0 ;;
  --broken)  exit 3 ;;
esac
EOF
chmod +x "$WORK/tool.sh"
export MARKER="$WORK/marker"

cat > "$CFG" <<EOF
{ "preflight": { "local_checks": [
    { "name": "commit hooks", "check": "$WORK/tool.sh --check" } ] } }
EOF
rm -f "$MARKER"
run r1-fail-no-repair
assert_true "check fails, no repair declared: exit 1 (fail-closed)" "[ '$RC' -eq 1 ]"
assert_true "check fails: stdout names the outcome per check (name whitespace folded to one token)" \
  "grep -q 'PREFLIGHT local checks: FAIL commit_hooks=FAIL' '$WORK/r1-fail-no-repair.log'"
assert_true "check fails: stderr says PREFLIGHT stops fail-closed" \
  "grep -q 'fail-closed' '$WORK/r1-fail-no-repair.log'"

cat > "$CFG" <<EOF
{ "preflight": { "local_checks": [
    { "name": "commit-hooks", "check": "$WORK/tool.sh --check", "repair": "$WORK/tool.sh --install" },
    { "check": "true" } ] } }
EOF
rm -f "$MARKER"
run r1-repair
assert_true "check fails, repair declared: repair runs, re-check passes → exit 0" "[ '$RC' -eq 0 ]"
assert_true "repair path: the marker the repair creates exists (repair actually ran)" "[ -f '$MARKER' ]"
assert_true "repair path: outcome is PASS(repaired) for the repaired check and PASS for the other" \
  "grep -q 'PREFLIGHT local checks: PASS commit-hooks=PASS(repaired) true=PASS' '$WORK/r1-repair.log'"

run r1-already-pass
assert_true "check already passes: exit 0 and PASS without repair" \
  "[ '$RC' -eq 0 ] && grep -q 'commit-hooks=PASS true=PASS' '$WORK/r1-already-pass.log'"

rm -f "$MARKER"
run r1-no-repair-flag --no-repair
assert_true "--no-repair: a declared repair is not run → exit 1, FAIL(repair-declined)" \
  "[ '$RC' -eq 1 ] && grep -q 'commit-hooks=FAIL(repair-declined)' '$WORK/r1-no-repair-flag.log' && [ ! -f '$MARKER' ]"

cat > "$CFG" <<EOF
{ "preflight": { "local_checks": [
    { "name": "still-broken", "check": "$WORK/tool.sh --broken", "repair": "$WORK/tool.sh --install" } ] } }
EOF
run r1-after-repair
assert_true "repair runs but re-check still fails: exit 1, FAIL(after-repair)" \
  "[ '$RC' -eq 1 ] && grep -q 'still-broken=FAIL(after-repair)' '$WORK/r1-after-repair.log'"

echo "=== declaration errors are exit 2, never a silent no-op ==="
echo '{ "preflight": { "local_checks": "bash x.sh" } }' > "$CFG"
run e-list-type
assert_true "local_checks not an array: exit 2" "[ '$RC' -eq 2 ]"
echo '{ "preflight": [] }' > "$CFG"
run e-section-type
assert_true ".preflight not an object: exit 2" "[ '$RC' -eq 2 ]"
echo '{ "preflight": { "local_checks": [ { "name": "x" } ] } }' > "$CFG"
run e-no-check
assert_true "entry without a string check: exit 2, names the entry index" \
  "[ '$RC' -eq 2 ] && grep -q 'local_checks\[0\]' '$WORK/e-no-check.log'"
echo '{ not json' > "$CFG"
run e-malformed
assert_true "malformed JSON: exit 2" "[ '$RC' -eq 2 ]"

echo "=== requirement 3: ledger record only; state file untouched; ledger check clean ==="
echo '{ "issue": "#1", "active": true }' > "$WORK/.autoflow/issue-1.json"
cp "$WORK/.autoflow/issue-1.json" "$WORK/state-before.json"
echo '{ "preflight": { "local_checks": [ { "name": "ok", "check": "true" } ] } }' > "$CFG"
run r3-ledger
assert_true "state file is byte-identical after a run" "cmp -s '$WORK/.autoflow/issue-1.json' '$WORK/state-before.json'"
assert_true "ledger record is a level-3 heading with the cycle and one result line" \
  "grep -q '^### preflight-local-checks | cycle: 2\$' '$LEDGER' && grep -q -- '^- result: PREFLIGHT local checks: PASS ok=PASS\$' '$LEDGER'"
assert_true "ledger-entry-id.sh check stays clean over the records (no identifier required)" \
  "bash '$LEDGER_ID' check '$LEDGER' >/dev/null 2>&1"
assert_true "ledger records are append-only across runs (every prior record still present)" \
  "[ \$(grep -c '^### preflight-local-checks | cycle: 2' '$LEDGER') -ge 8 ]"

echo "=== framework knows no tool ==="
assert_true "script source names no specific hook/lint tool (husky, lint-staged, prettier, eslint)" \
  "! grep -qiE 'husky|lint-staged|prettier|eslint' '$SCRIPT'"

echo "=== delivery + playbook ==="
assert_true "manifest ships scripts/preflight/local-checks.sh as a root-layer copy artifact" \
  "jq -e '.artifacts[] | select(.source == \"scripts/preflight/local-checks.sh\" and .kind == \"copy\" and .tier == \"root-layer\")' '$MANIFEST' >/dev/null 2>&1"
assert_true "manifest sha256 for the script equals the current source hash" \
  "[ \"\$(jq -r '.artifacts[] | select(.source == \"scripts/preflight/local-checks.sh\") | .sha256' '$MANIFEST')\" = \"\$(shasum -a 256 '$SCRIPT' | awk '{print \$1}')\" ]"
assert_true "PREFLIGHT playbook names local-checks.sh as a fail-closed stop condition" \
  "awk '/^## PREFLIGHT/{f=1;next} f && /^## /{exit} f && /scripts\\/preflight\\/local-checks\\.sh/ {found=1} END {exit !found}' '$GUIDE_MD'"
assert_true "PREFLIGHT playbook names the declaration key preflight.local_checks" \
  "awk '/^## PREFLIGHT/{f=1;next} f && /^## /{exit} f && /preflight\\.local_checks/ {found=1} END {exit !found}' '$GUIDE_MD'"

echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
