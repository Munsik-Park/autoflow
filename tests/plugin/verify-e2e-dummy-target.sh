#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: throwaway dummy-target E2E suite — the plugin alone, against an
# unstamped target (ADR-0027 D1, D3, D4)
# =============================================================================
# The plugin package is laid out the way an install lays it out
# (tests/lib/plugin-package.sh: <config>/plugins/cache/autoflow/autoflow/
# <version>/), and a realistic, zero-submodule dummy library — its own git
# history, a foreign package.json/src/ payload, a README and a CLAUDE.md of its
# own, and no AutoFlow file at all — is the target and the working directory of
# every run. The PREFLIGHT scripts are run by their installed path and the gate
# hook with CLAUDE_PLUGIN_ROOT naming the installed copy and CLAUDE_PROJECT_DIR
# the target, as the harness runs them. `gh` is a stub that answers every
# lookup with an empty list, so no run reaches the network. Plain bash +
# jq/git/tar/grep (no bats, no node/npm).
#
# Legs (category: packaging):
#
#   E1  the dummy target is realistic and unstamped
#     E1a  foreign payload present, no .gitmodules, no AutoFlow file
#
#   E2  the PREFLIGHT scripts resolve the plugin root, and the state lives
#       under the record root, outside the target (issue #466)
#     E2a  cycle-status.sh reports the plugin record: the installed root, the
#          plugin name and version, and `not a git work tree`; and the record
#          root, HOME's default
#     E2b  cycle-status.sh run from a git work tree (this checkout) reports
#          its HEAD
#     E2c  the target's attempt under the record root is the one cycle-status.sh
#          reports, and the entry it prints is its resume
#     E2d  local-checks.sh writes its record to the attempt's ledger, and the
#          plugin root gains no ledger
#
#   E3  the gate hook, run as the harness runs it
#     E3a  a benign command is allowed (exit 0)
#     E3b  the hook reads the state of the target's attempt: `git push` is
#          admitted with no state file and denied once the attempt holds an
#          active one with no gate scores
#     E3c  the ledger advisory finds its helper in the plugin root, and its
#          cache lands at the record root
#     E3e  after every run above, the target's `git status --porcelain` is
#          empty: AutoFlow left no file in a tree that ignores none
#     E3d  the target's spawn policy wins over the plugin default — in the
#          readout and in the hook's advisory
#
#   E4  the target check runs from the plugin root, fail-closed
#     E4a  a target with no policy of its own and no suite-plane opt-in: exit 0
#     E4b  a target policy that agrees with the loaded definitions: exit 0
#     E4c  a target policy that lacks a row the default carries: exit 1, the
#          row named
#     E4d  an opted-in target with a header-less suite: exit 1, the suite
#          named; with the header back-filled: exit 0
#
#   E5  nothing was written into the installed plugin
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../lib/plugin-package.sh
. "$REPO_ROOT/tests/lib/plugin-package.sh"

PASS_COUNT=0
FAIL_COUNT=0
pass()  { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
failc() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s -- %s\n' "$1" "$2"; }

for _tool in jq git tar; do
  command -v "$_tool" >/dev/null 2>&1 || { echo "verify-e2e-dummy-target: $_tool is required" >&2; exit 2; }
done

WORK="$(mktemp -d)"
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT

CFG="$WORK/config"
ROOT="$(install_plugin_package "$REPO_ROOT" "$CFG")" || { echo "verify-e2e-dummy-target: package copy failed" >&2; exit 2; }
VERSION="$(jq -r '.version' "$REPO_ROOT/.claude-plugin/plugin.json")"
HOOK="$ROOT/hooks/check-autoflow-gate.sh"
find "$ROOT" -type f | LC_ALL=C sort > "$WORK/root-before.list"

# The stub gh: every lookup answers an empty list; nothing reaches the network.
STUB="$WORK/stub-bin"
mkdir -p "$STUB"
printf '#!/usr/bin/env bash\necho "[]"\n' > "$STUB/gh"
chmod +x "$STUB/gh"

# HOME is a scratch directory: the user file and the record root (its default,
# HOME/.autoflow — scripts/lib/records.sh) are the test's own, never the
# operator's.
TEST_HOME="$WORK/home"
mkdir -p "$TEST_HOME"
RECORD_ROOT="$TEST_HOME/.autoflow"

# in_target <dir> <cmd…> — a command run as PREFLIGHT runs it: the working
# directory the target, the developer's own session variables cleared.
in_target() {
  local _d="$1"; shift
  (cd "$_d" && env -u CLAUDE_PLUGIN_ROOT -u CLAUDE_PROJECT_DIR -u AUTOFLOW_SPAWN_POLICY \
    HOME="$TEST_HOME" CLAUDE_CONFIG_DIR="$CFG" PATH="$STUB:$PATH" "$@")
}
# run_hook <target> — the gate hook as the harness runs it.
run_hook() {
  (cd "$1" && env -u AUTOFLOW_SPAWN_POLICY HOME="$TEST_HOME" CLAUDE_CONFIG_DIR="$CFG" PATH="$STUB:$PATH" \
    CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PROJECT_DIR="$1" bash "$HOOK")
}
bash_payload()  { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(printf '%s' "$1" | jq -Rs .)"; }
agent_payload() { printf '{"tool_name":"Agent","tool_input":{"subagent_type":"%s","model":"%s","prompt":"x"}}' "$1" "$2"; }

GIT_ID=(-c user.email=test@example.com -c user.name=test -c commit.gpgsign=false)

# make_dummy_target <dir> — a structurally real, zero-submodule JS-style
# library with its own history and an origin, and no AutoFlow file.
make_dummy_target() {
  local d="$1"
  mkdir -p "$d/src"
  cat > "$d/package.json" <<'PKGJSON'
{
  "name": "throwaway-lib",
  "version": "0.0.0",
  "private": true,
  "description": "throwaway dummy library target for AutoFlow's E2E suite"
}
PKGJSON
  printf '// throwaway-lib\nmodule.exports = function add(a, b) {\n  return a + b;\n};\n' > "$d/src/index.js"
  printf '# throwaway-lib\n\nA throwaway dummy library target. Never published.\n' > "$d/README.md"
  printf '# throwaway-lib operating notes\n\nThe target project'"'"'s own prose.\n' > "$d/CLAUDE.md"
  ( cd "$d" && git init -q && git "${GIT_ID[@]}" add -A \
    && git "${GIT_ID[@]}" commit -q -m "initial commit (dummy target)" \
    && git remote add origin https://github.com/example/throwaway-lib.git )
}

# target_policy <dir> [<jq filter>] — the target's own spawn policy: the
# plugin default with every autoflow-evaluator row on haiku, then <jq filter>.
target_policy() {
  mkdir -p "$1/.claude/autoflow"
  jq '.phases |= with_entries(if .value.agent_type == "autoflow-evaluator" then .value.model = "haiku" else . end)'"${2:+ | $2}" \
    "$ROOT/.claude/autoflow/spawn-policy.json" > "$1/.claude/autoflow/spawn-policy.json"
}

KEY="example__throwaway-lib"

# ── E1 ──────────────────────────────────────────────────────────────────────
echo "== E1: the dummy target is realistic and unstamped =="
T="$WORK/dummy"
make_dummy_target "$T"
if [ -f "$T/package.json" ] && [ -f "$T/src/index.js" ] && [ -f "$T/README.md" ] && [ ! -e "$T/.gitmodules" ] \
   && [ ! -e "$T/scripts" ] && [ ! -e "$T/docs" ] && [ ! -e "$T/.claude" ] && [ ! -e "$T/.autoflow" ]; then
  pass "E1a: foreign payload present, no .gitmodules, no AutoFlow file"
else
  failc "E1a" "the fixture is not a realistic unstamped target: $(cd "$T" && find . -path ./.git -prune -o -print | LC_ALL=C sort | tr '\n' ' ')"
fi

# ── E2 ──────────────────────────────────────────────────────────────────────
echo "== E2: the PREFLIGHT scripts resolve the plugin root; the state lives under the record root =="
in_target "$T" bash "$ROOT/scripts/preflight/cycle-status.sh" >"$WORK/e2a.out" 2>&1; rc=$?
if [ "$rc" -eq 0 ] && grep -qxF "autoflow root: $ROOT" "$WORK/e2a.out" \
   && grep -qxF "  plugin: autoflow $VERSION" "$WORK/e2a.out" \
   && grep -qxF "  git: not a git work tree" "$WORK/e2a.out" \
   && grep -qxF "record root: $RECORD_ROOT" "$WORK/e2a.out" \
   && grep -qxF "attempts: none" "$WORK/e2a.out"; then
  pass "E2a: cycle-status.sh reports the plugin record — root $ROOT, autoflow $VERSION, not a git work tree — and the record root $RECORD_ROOT"
else
  failc "E2a" "rc=$rc out=$(tr '\n' '|' < "$WORK/e2a.out")"
fi

in_target "$T" bash "$REPO_ROOT/scripts/preflight/cycle-status.sh" >"$WORK/e2b.out" 2>&1; rc=$?
head_sha="$(git -C "$REPO_ROOT" rev-parse HEAD)"
if [ "$rc" -eq 0 ] && grep -qxF "autoflow root: $REPO_ROOT" "$WORK/e2b.out" \
   && grep -qE "^  git: $head_sha (clean|dirty \([0-9]+ path\(s\)\))\$" "$WORK/e2b.out"; then
  pass "E2b: run from a git work tree (a --plugin-dir clone), cycle-status.sh reports its HEAD and dirty state"
else
  failc "E2b" "rc=$rc head=$head_sha out=$(tr '\n' '|' < "$WORK/e2b.out")"
fi

# The attempt's record directory and its owner file are made when the cycle
# creates the attempt, before its criterion review stage (autoflow-records new —
# which fetches, so it is made here by hand), and the orchestrator writes the
# state file at PREFLIGHT's end (docs/state-tracking.md).
SD="$RECORD_ROOT/$KEY/2026-10-17-000000-issue-7"
mkdir -p "$SD"
printf '%s\n' "$T" > "$SD/checkout"
cat > "$SD/issue-7.json" <<'STATE'
{
  "active": true,
  "issue": "#7",
  "title": "e2e",
  "date": "2026-10-17",
  "branch": "dev/2026-10-17-000000-issue-7",
  "cycle": 1,
  "mode": "new-issue",
  "phase": "in-progress",
  "phases": {
    "gate_hypothesis": { "evaluator": "", "scores": {}, "verdict": "skipped (non-bug issue)" },
    "gate_plan":       { "evaluator": "", "scores": {} },
    "audit":           { "evaluator": "", "scores": {} },
    "gate_quality":    { "evaluator": "", "scores": {} }
  }
}
STATE
in_target "$T" bash "$ROOT/scripts/preflight/cycle-status.sh" --issue 7 >"$WORK/e2c.out" 2>&1; rc=$?
if [ "$rc" -eq 0 ] && grep -qxF "attempt 2026-10-17-000000-issue-7 (issue #7): owner=this state=active=true phase=in-progress mode=new-issue cycle=1" "$WORK/e2c.out" \
   && grep -qxF "  branch: dev/2026-10-17-000000-issue-7 (local=no origin=no)" "$WORK/e2c.out" \
   && grep -qxF "entry: resume 2026-10-17-000000-issue-7" "$WORK/e2c.out"; then
  pass "E2c: the target's attempt under the record root ($SD) is the one cycle-status.sh reports, entered as its resume"
else
  failc "E2c" "rc=$rc out=$(tr '\n' '|' < "$WORK/e2c.out")"
fi

LEDGER="$SD/issue-7-ledger.md"
in_target "$T/src" bash "$ROOT/scripts/preflight/local-checks.sh" --ledger "$LEDGER" --cycle 1 \
  >"$WORK/e2d.out" 2>&1; rc=$?
if [ "$rc" -eq 0 ] && grep -qxF "### preflight-local-checks | cycle: 1" "$LEDGER" \
   && grep -qxF -- "- result: PREFLIGHT local checks: none declared" "$LEDGER" \
   && [ -z "$(find "$ROOT" -name 'issue-7-ledger.md')" ]; then
  pass "E2d: local-checks.sh, run from a subdirectory, records into the attempt's ledger; the plugin root gains none"
else
  failc "E2d" "rc=$rc out=$(tr '\n' '|' < "$WORK/e2d.out") root-ledger=$(find "$ROOT" -name 'issue-7-ledger.md' | head -1)"
fi

# ── E3 ──────────────────────────────────────────────────────────────────────
echo "== E3: the gate hook, run as the harness runs it =="
# The allow case is the smoke: exit 0 cannot come from a script bash fails to
# parse, whose exit status (2) coincides with the deny status.
bash_payload ls | run_hook "$T" >/dev/null 2>"$WORK/e3a.err"; rc=$?
if [ "$rc" -eq 0 ]; then
  pass "E3a: the installed gate hook allows a benign command (exit 0)"
else
  failc "E3a" "rc=$rc stderr=$(tr '\n' '|' < "$WORK/e3a.err")"
fi

PUSH='git push -u origin dev/2026-10-17-000000-issue-7'
mv "$SD/issue-7.json" "$WORK/issue-7.json.held"
bash_payload "$PUSH" | run_hook "$T" >/dev/null 2>"$WORK/e3b0.err"; rc0=$?
mv "$WORK/issue-7.json.held" "$SD/issue-7.json"
bash_payload "$PUSH" | run_hook "$T" >/dev/null 2>"$WORK/e3b1.err"; rc1=$?
if [ "$rc0" -eq 0 ] && [ "$rc1" -eq 2 ] && grep -q 'BLOCKED' "$WORK/e3b1.err"; then
  pass "E3b: the hook reads the target's attempt — the push is admitted with no state file and denied with the active one"
else
  failc "E3b" "rc-without-state=$rc0 rc-with-state=$rc1 stderr=$(tr '\n' '|' < "$WORK/e3b1.err")"
fi

printf '\n## no identifier here\n' >> "$LEDGER"
out=$(bash_payload ls | run_hook "$T" 2>"$WORK/e3c.err"); rc=$?
if [ "$rc" -eq 0 ] && grep -q 'decision-ledger identifier defect' "$WORK/e3c.err" \
   && grep -qF "$ROOT/scripts/ledger/ledger-entry-id.sh next" "$WORK/e3c.err" \
   && printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | test("identifier defect")' >/dev/null 2>&1 \
   && [ -f "$RECORD_ROOT/.ledger-check-cache" ] && [ ! -e "$T/.autoflow" ] && [ ! -e "$ROOT/.autoflow/.ledger-check-cache" ]; then
  pass "E3c: the ledger advisory runs the plugin's helper ($ROOT/scripts/ledger/) and caches at the record root"
else
  failc "E3c" "rc=$rc stderr=$(tr '\n' '|' < "$WORK/e3c.err")"
fi

porcelain="$(git -C "$T" status --porcelain)"
if [ -z "$porcelain" ]; then
  pass "E3e: after the PREFLIGHT scripts and the hook, the target's git status --porcelain is empty — no AutoFlow file in a tree that ignores none"
else
  failc "E3e" "the target's tree carries: $(printf '%s' "$porcelain" | tr '\n' '|')"
fi

target_policy "$T"
got="$(in_target "$T/src" bash "$ROOT/scripts/spawn-policy/spawn-policy.sh" model gate-plan 2>&1)"
default_model="$(jq -r '.phases["gate-plan"].model' "$ROOT/.claude/autoflow/spawn-policy.json")"
agent_payload autoflow-evaluator opus | run_hook "$T" >/dev/null 2>"$WORK/e3d.err"; rc=$?
if [ "$got" = "haiku" ] && [ "$default_model" != "haiku" ] && [ "$rc" -eq 0 ] \
   && grep -q "outside the spawn policy's admitted set" "$WORK/e3d.err" && grep -q 'Admitted: haiku' "$WORK/e3d.err"; then
  pass "E3d: the target's spawn policy wins over the plugin default ($default_model) in the readout and in the hook's advisory"
else
  failc "E3d" "readout='$got' default='$default_model' rc=$rc stderr=$(tr '\n' '|' < "$WORK/e3d.err")"
fi

# ── E4 ──────────────────────────────────────────────────────────────────────
echo "== E4: the target check runs from the plugin root, fail-closed =="
TC="$ROOT/scripts/preflight/target-check.sh"
T4="$WORK/dummy-check"
make_dummy_target "$T4"

in_target "$T4" bash "$TC" >"$WORK/e4a.out" 2>&1; rc=$?
if [ "$rc" -eq 0 ] && grep -q '^PASS: D6: the target keeps no .claude/autoflow/spawn-policy.json' "$WORK/e4a.out" \
   && grep -q '^PASS: D7: suite plane not opted in' "$WORK/e4a.out"; then
  pass "E4a: no target policy and no suite-plane opt-in — exit 0"
else
  failc "E4a" "rc=$rc out=$(tr '\n' '|' < "$WORK/e4a.out")"
fi

target_policy "$T4"
in_target "$T4" bash "$TC" >"$WORK/e4b.out" 2>&1; rc=$?
if [ "$rc" -eq 0 ] && grep -qF "PASS: D6: the target's policy ($T4/.claude/autoflow/spawn-policy.json) agrees with the loaded agent definitions ($ROOT/agents)" "$WORK/e4b.out"; then
  pass "E4b: a target policy with its own models that agrees with the loaded definitions — exit 0"
else
  failc "E4b" "rc=$rc out=$(tr '\n' '|' < "$WORK/e4b.out")"
fi

target_policy "$T4" 'del(.phases["gate-plan"])'
in_target "$T4" bash "$TC" >"$WORK/e4c.out" 2>&1; rc=$?
if [ "$rc" -eq 1 ] && grep -q "^FAIL: D6 -- missing phases row 'gate-plan'" "$WORK/e4c.out" \
   && grep -qx 'RESULT: target-check [1-9][0-9]* failed' "$WORK/e4c.out"; then
  pass "E4c: a target policy lacking the default's gate-plan row — exit 1, the row named"
else
  failc "E4c" "rc=$rc out=$(tr '\n' '|' < "$WORK/e4c.out")"
fi

rm -f "$T4/.claude/autoflow/spawn-policy.json"
printf '{ "tests": { "suite_plane": true } }\n' > "$T4/.claude/autoflow.local.json"
mkdir -p "$T4/tests"
printf '#!/usr/bin/env bash\nexit 0\n' > "$T4/tests/no-header.sh"
in_target "$T4" bash "$TC" >"$WORK/e4d1.out" 2>&1; rc1=$?
printf '#!/usr/bin/env bash\n# ci-subject: src/\n# budget-secs: 10\nexit 0\n' > "$T4/tests/no-header.sh"
in_target "$T4" bash "$TC" >"$WORK/e4d2.out" 2>&1; rc2=$?
if [ "$rc1" -eq 1 ] && grep -q '^FAIL: D7 -- tests/no-header.sh declares no usable' "$WORK/e4d1.out" \
   && [ "$rc2" -eq 0 ] && grep -q '^PASS: D7: suite headers OK' "$WORK/e4d2.out"; then
  pass "E4d: an opted-in target — a header-less suite is exit 1 and named; back-filled, exit 0"
else
  failc "E4d" "rc1=$rc1 rc2=$rc2 out1=$(tr '\n' '|' < "$WORK/e4d1.out") out2=$(tr '\n' '|' < "$WORK/e4d2.out")"
fi

# ── E5 ──────────────────────────────────────────────────────────────────────
echo "== E5: nothing was written into the installed plugin =="
find "$ROOT" -type f | LC_ALL=C sort > "$WORK/root-after.list"
if cmp -s "$WORK/root-before.list" "$WORK/root-after.list"; then
  pass "E5: the installed plugin's file set is unchanged by every run above"
else
  failc "E5" "added or removed under $ROOT: $(diff "$WORK/root-before.list" "$WORK/root-after.list" | grep '^[<>]' | tr '\n' ' ')"
fi

echo "=============================================="
echo "RESULT: $PASS_COUNT passed, $FAIL_COUNT failed (of $((PASS_COUNT + FAIL_COUNT)) checks)"
[ "$FAIL_COUNT" -eq 0 ]
