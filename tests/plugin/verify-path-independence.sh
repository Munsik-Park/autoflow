#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: path independence of the shipped hook and scripts
# =============================================================================
# The shipped gate hook and scripts resolve AutoFlow's own files from the
# AutoFlow tree they run from, and the target's files from the target, so they
# work from a plugin root apart from the target. Each leg builds the two trees
# in a mktemp scratch dir and runs the shipped files from there. Plain bash +
# jq/git only (no bats, no node/npm).
#
# Legs (category: packaging):
#
#   H   gate-hook helper lookup and message paths
#     H1  CLAUDE_PLUGIN_ROOT set: the plugin root's ledger helper runs, never
#         the target's copy, and the advisory reaches the model
#     H2  no CLAUDE_PLUGIN_ROOT, the hook at <root>/hooks/: the helper is found
#         beside it
#     H3  a plugin root that carries no helper runs none: the target's copy of
#         it is never executed (ADR-0027 D3)
#     H4  a deny message names the plugin root's script and document by
#         absolute path
#
#   P   spawn-policy lookup order
#     P1  CLAUDE_PROJECT_DIR's policy wins over the AutoFlow default
#     P2  without CLAUDE_PROJECT_DIR, the policy at the working directory's git
#         toplevel wins (run from a subdirectory)
#     P3  a target without a policy falls back to the AutoFlow default
#     P4  AUTOFLOW_SPAWN_POLICY wins over both
#     P6  `check` reads the agent definitions at <root>/agents
#     P7  the hook advisory compares a spawn against the target's policy
#
#   S   suite-family scripts' default root
#     S1  check-cycle-layer-index.sh examines the working directory's git
#         toplevel, not the tree it ships in
#     S2  select-suites.sh --check-headers examines the same root
#     S3  outside a git repository, with no --root: usage exit 2
#
#   W   codex review wrapper prompt
#     W1  the prompt names the plugin root's .codex/review.md by absolute path
#     W2  a plugin root without .codex/review.md: exit 2, codex not started
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK_SRC="$REPO_ROOT/hooks/check-autoflow-gate.sh"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

pass()  { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
failc() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s [stage:%s] -- %s\n' "$1" "$2" "$3"; }

for _tool in jq git; do
  command -v "$_tool" >/dev/null 2>&1 || { echo "verify-path-independence: $_tool is required" >&2; exit 2; }
done

WORK="$(mktemp -d)"
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT

# Every leg runs with the harness variables cleared, so the developer's own
# session cannot steer a resolution; each leg sets what it tests. HOME is an
# empty directory, so the operator's ~/.autoflow/config.json (the user-level
# external-reviewer file, docs/reviewer-backend.md > Config location) is never
# read.
run_clean() { env -u CLAUDE_PLUGIN_ROOT -u CLAUDE_PROJECT_DIR -u AUTOFLOW_SPAWN_POLICY \
  -u REVIEW_CONFIG_PATH CLAUDE_CONFIG_DIR="$WORK/empty-config" HOME="$WORK/empty-home" "$@"; }
mkdir -p "$WORK/empty-config" "$WORK/empty-home"

git_init() {
  ( cd "$1" && git init -q \
    && git -c user.email=test@example.com -c user.name=test commit -q --allow-empty -m init )
}

# make_plugin_root <dir> — an AutoFlow tree laid out as a plugin root: hooks/,
# agents/, scripts/, docs/, .codex/ and the default spawn policy, apart from
# any target.
make_plugin_root() {
  local d="$1"
  mkdir -p "$d/hooks" "$d/agents" "$d/.claude/autoflow" "$d/.codex"
  cp "$HOOK_SRC" "$d/hooks/check-autoflow-gate.sh"
  cp "$REPO_ROOT"/agents/autoflow-*.md "$d/agents/"
  cp -R "$REPO_ROOT/scripts" "$d/scripts"
  cp -R "$REPO_ROOT/docs" "$d/docs"
  cp "$REPO_ROOT/.codex/review.md" "$d/.codex/review.md"
  cp "$REPO_ROOT/.claude/autoflow/spawn-policy.json" "$d/.claude/autoflow/spawn-policy.json"
}

# make_target <dir> — a git repository with a defective ledger, so the hook's
# ledger advisory has something to report whenever its helper runs.
make_target() {
  local d="$1"
  mkdir -p "$d/.autoflow/o__r-issue-1"
  git_init "$d"
  printf '# ledger\n\n## no identifier here\n' > "$d/.autoflow/o__r-issue-1/issue-1-ledger.md"
}

# target_policy <dir> — the target's own policy: the default with every
# autoflow-evaluator row on haiku, so the two policies answer differently.
target_policy() {
  mkdir -p "$1/.claude/autoflow"
  jq '.phases |= with_entries(if .value.agent_type == "autoflow-evaluator" then .value.model = "haiku" else . end)' \
    "$REPO_ROOT/.claude/autoflow/spawn-policy.json" > "$1/.claude/autoflow/spawn-policy.json"
}

bash_payload()  { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(printf '%s' "$1" | jq -Rs .)"; }
agent_payload() { printf '{"tool_name":"Agent","tool_input":{"subagent_type":"%s","model":"%s","prompt":"x"}}' "$1" "$2"; }

PLUGIN="$WORK/plugin-root"
make_plugin_root "$PLUGIN"

# ── H: gate-hook helper lookup and message paths ─────────────────────────────
echo "== H: gate-hook helper lookup and message paths =="

T="$WORK/target-h"
make_target "$T"
mkdir -p "$T/scripts/ledger"
DECOY_MARK="$WORK/decoy-ran"
printf '#!/usr/bin/env bash\ntouch %q\nexit 0\n' "$DECOY_MARK" > "$T/scripts/ledger/ledger-entry-id.sh"

out=$(bash_payload ls | run_clean CLAUDE_PLUGIN_ROOT="$PLUGIN" CLAUDE_PROJECT_DIR="$T" \
  bash "$PLUGIN/hooks/check-autoflow-gate.sh" 2>"$WORK/h1.err"); rc=$?
if [ "$rc" -eq 0 ] && [ ! -e "$DECOY_MARK" ] && grep -q 'decision-ledger identifier defect' "$WORK/h1.err" \
   && printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | test("identifier defect")' >/dev/null 2>&1 \
   && grep -qF "$PLUGIN/scripts/ledger/ledger-entry-id.sh next" "$WORK/h1.err"; then
  pass "H1: the plugin root's ledger helper runs (the target's copy does not), and the warning names it by absolute path"
else
  failc "H1" "hook" "rc=$rc decoy-ran=$([ -e "$DECOY_MARK" ] && echo yes || echo no) stderr=$(head -c 300 "$WORK/h1.err")"
fi

rm -f "$DECOY_MARK" "$T/.autoflow/.ledger-check-cache"
bash_payload ls | run_clean CLAUDE_PROJECT_DIR="$T" bash "$PLUGIN/hooks/check-autoflow-gate.sh" >/dev/null 2>"$WORK/h2.err"; rc=$?
if [ "$rc" -eq 0 ] && [ ! -e "$DECOY_MARK" ] && grep -q 'decision-ledger identifier defect' "$WORK/h2.err"; then
  pass "H2: without CLAUDE_PLUGIN_ROOT the hook at <root>/hooks/ finds the helper beside it"
else
  failc "H2" "hook" "rc=$rc decoy-ran=$([ -e "$DECOY_MARK" ] && echo yes || echo no) stderr=$(head -c 300 "$WORK/h2.err")"
fi

# A plugin root that carries hooks/ only: the target's decoy helper (make_target
# above, under $T) is the only copy of the helper anywhere the hook could look.
BARE="$WORK/bare-root"
mkdir -p "$BARE/hooks"
cp "$HOOK_SRC" "$BARE/hooks/check-autoflow-gate.sh"
rm -f "$DECOY_MARK" "$T/.autoflow/.ledger-check-cache"
bash_payload ls | run_clean CLAUDE_PLUGIN_ROOT="$BARE" CLAUDE_PROJECT_DIR="$T" \
  bash "$BARE/hooks/check-autoflow-gate.sh" >/dev/null 2>"$WORK/h3.err"; rc=$?
if [ "$rc" -eq 0 ] && [ ! -e "$DECOY_MARK" ] && ! grep -q 'decision-ledger identifier defect' "$WORK/h3.err"; then
  pass "H3: a plugin root without the helper runs none — the target's copy is never executed"
else
  failc "H3" "hook" "rc=$rc decoy-ran=$([ -e "$DECOY_MARK" ] && echo yes || echo no) stderr=$(head -c 300 "$WORK/h3.err")"
fi

bash_payload 'gh issue create --title x' | run_clean CLAUDE_PLUGIN_ROOT="$PLUGIN" CLAUDE_PROJECT_DIR="$T" \
  bash "$PLUGIN/hooks/check-autoflow-gate.sh" >/dev/null 2>"$WORK/h4.err"; rc=$?
if [ "$rc" -eq 2 ] && grep -qF "then run: $PLUGIN/scripts/issue/create-issue.sh --draft .autoflow/<name>.md" "$WORK/h4.err" \
   && grep -qF "per $PLUGIN/docs/issue-proposal.md," "$WORK/h4.err"; then
  pass "H4: the deny names the plugin root's script and document by absolute path (the target path stays relative)"
else
  failc "H4" "hook" "rc=$rc stderr=$(head -c 400 "$WORK/h4.err")"
fi

# ── P: spawn-policy lookup order ─────────────────────────────────────────────
echo "== P: spawn-policy lookup order =="

SP="$PLUGIN/scripts/spawn-policy/spawn-policy.sh"
TP="$WORK/target-p"
git_init "$(mkdir -p "$TP" && echo "$TP")"
target_policy "$TP"
mkdir -p "$TP/sub/dir"

got=$(cd "$WORK" && run_clean CLAUDE_PROJECT_DIR="$TP" bash "$SP" model gate-plan 2>&1)
[ "$got" = "haiku" ] && pass "P1: CLAUDE_PROJECT_DIR's policy wins over the AutoFlow default" \
  || failc "P1" "readout" "got '$got', want 'haiku'"

got=$(cd "$TP/sub/dir" && run_clean bash "$SP" model gate-plan 2>&1)
[ "$got" = "haiku" ] && pass "P2: without CLAUDE_PROJECT_DIR, the working directory's git toplevel policy wins" \
  || failc "P2" "readout" "got '$got', want 'haiku'"

TN="$WORK/target-nopolicy"
git_init "$(mkdir -p "$TN" && echo "$TN")"
want=$(jq -r '.phases["gate-plan"].model' "$PLUGIN/.claude/autoflow/spawn-policy.json")
got=$(cd "$TN" && run_clean bash "$SP" model gate-plan 2>&1)
[ "$got" = "$want" ] && pass "P3: a target without a policy falls back to the AutoFlow default ($want)" \
  || failc "P3" "readout" "got '$got', want '$want'"

OVR="$WORK/override.json"
jq '.phases["gate-plan"].model = "override-model"' "$PLUGIN/.claude/autoflow/spawn-policy.json" > "$OVR"
got=$(cd "$TP" && run_clean CLAUDE_PROJECT_DIR="$TP" AUTOFLOW_SPAWN_POLICY="$OVR" bash "$SP" model gate-plan 2>&1)
[ "$got" = "override-model" ] && pass "P4: AUTOFLOW_SPAWN_POLICY wins over the target's policy and the default" \
  || failc "P4" "readout" "got '$got', want 'override-model'"

if (cd "$TP" && run_clean CLAUDE_PROJECT_DIR="$TP" bash "$SP" check >"$WORK/p6.out" 2>&1); then
  pass "P6: check validates the target's policy against the agent definitions at <root>/agents"
else
  failc "P6" "check" "$(head -c 400 "$WORK/p6.out")"
fi

agent_payload autoflow-evaluator opus | run_clean CLAUDE_PLUGIN_ROOT="$PLUGIN" CLAUDE_PROJECT_DIR="$TP" \
  bash "$PLUGIN/hooks/check-autoflow-gate.sh" >/dev/null 2>"$WORK/p7.err"; rc=$?
agent_payload autoflow-evaluator opus | run_clean CLAUDE_PLUGIN_ROOT="$PLUGIN" CLAUDE_PROJECT_DIR="$TN" \
  bash "$PLUGIN/hooks/check-autoflow-gate.sh" >/dev/null 2>"$WORK/p7n.err"; rcn=$?
if [ "$rc" -eq 0 ] && grep -q "outside the spawn policy's admitted set" "$WORK/p7.err" && grep -q 'Admitted: haiku' "$WORK/p7.err" \
   && [ "$rcn" -eq 0 ] && ! grep -q "outside the spawn policy's admitted set" "$WORK/p7n.err"; then
  pass "P7: the hook advisory compares a spawn against the target's policy, and against the default where the target has none"
else
  failc "P7" "hook" "rc=$rc rcn=$rcn target=$(head -c 300 "$WORK/p7.err") default=$(head -c 300 "$WORK/p7n.err")"
fi

# ── S: suite-family scripts' default root ────────────────────────────────────
echo "== S: suite-family scripts' default root =="

TT="$WORK/target-s"
git_init "$(mkdir -p "$TT" && echo "$TT")"
mkdir -p "$TT/.autoflow/o__r-issue-9/issue-9-local" "$TT/tests" "$TT/sub"
printf 'x\n' > "$TT/.autoflow/o__r-issue-9/issue-9-local/probe.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TT/tests/no-header.sh"
( cd "$TT" && git add -A && git -c user.email=test@example.com -c user.name=test commit -q -m fixture )

out=$(cd "$TT/sub" && run_clean bash "$PLUGIN/scripts/test/check-cycle-layer-index.sh" 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -qF '.autoflow/o__r-issue-9/issue-9-local/probe.sh'; then
  pass "S1: check-cycle-layer-index.sh examines the working directory's git toplevel"
else
  failc "S1" "run" "rc=$rc out=$(printf '%s' "$out" | head -c 300)"
fi

out=$(cd "$TT/sub" && run_clean bash "$PLUGIN/scripts/test/select-suites.sh" --check-headers 2>/dev/null); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -qx 'tests/no-header.sh'; then
  pass "S2: select-suites.sh --check-headers examines the working directory's git toplevel"
else
  failc "S2" "run" "rc=$rc out=$(printf '%s' "$out" | head -c 300)"
fi

NG="$WORK/not-git"
mkdir -p "$NG"
s3=""
for _s in run-suites.sh select-suites.sh check-cycle-layer-index.sh; do
  (cd "$NG" && GIT_CEILING_DIRECTORIES="$WORK" run_clean bash "$PLUGIN/scripts/test/$_s" >/dev/null 2>&1); s3="$s3 $_s=$?"
done
[ "$s3" = " run-suites.sh=2 select-suites.sh=2 check-cycle-layer-index.sh=2" ] \
  && pass "S3: outside a git repository with no --root, each script exits 2" \
  || failc "S3" "run" "exits:$s3"

# ── W: codex review wrapper prompt ───────────────────────────────────────────
echo "== W: codex review wrapper prompt =="

STUB="$WORK/stub-bin"
mkdir -p "$STUB"
cat > "$STUB/gh" <<'GH'
#!/usr/bin/env bash
printf 'OPEN\tdev/test\n'
GH
cat > "$STUB/codex" <<'CODEX'
#!/usr/bin/env bash
# The last argument is the prompt; record it and leave the review record.
for _a in "$@"; do _last="$_a"; done
printf '%s' "$_last" > "$CODEX_PROMPT_CAPTURE"
printf 'review\n' > "$CODEX_RECORD_OUT"
CODEX
chmod +x "$STUB/gh" "$STUB/codex"

# run_wrapper <wrapper> <target> <capture> — rc of the wrapper run in <target>.
run_wrapper() {
  rm -f "$3"
  (cd "$2" && run_clean PATH="$STUB:$PATH" CODEX_PROMPT_CAPTURE="$3" CODEX_RECORD_OUT="$2/rec/out.md" \
    bash "$1" --pr 7 --out rec/out.md >/dev/null 2>"$3.err")
}

TW="$WORK/target-w"
git_init "$(mkdir -p "$TW" && echo "$TW")"
run_wrapper "$PLUGIN/scripts/review/codex-review-pr.sh" "$TW" "$WORK/w1.prompt"; rc=$?
if [ "$rc" -eq 0 ] && grep -qF "the review convention at $PLUGIN/.codex/review.md." "$WORK/w1.prompt" \
   && grep -qF "in the Output Format of $PLUGIN/.codex/review.md," "$WORK/w1.prompt"; then
  pass "W1: the prompt names the plugin root's .codex/review.md by absolute path"
else
  failc "W1" "wrapper" "rc=$rc prompt=$(head -c 400 "$WORK/w1.prompt" 2>/dev/null) err=$(head -c 200 "$WORK/w1.prompt.err")"
fi

NOGUIDE="$WORK/plugin-noguide"
mkdir -p "$NOGUIDE"
cp -R "$REPO_ROOT/scripts" "$NOGUIDE/scripts"
run_wrapper "$NOGUIDE/scripts/review/codex-review-pr.sh" "$TW" "$WORK/w2.prompt"; rc=$?
if [ "$rc" -eq 2 ] && [ ! -e "$WORK/w2.prompt" ] && grep -q 'review convention is missing' "$WORK/w2.prompt.err"; then
  pass "W2: a tree without .codex/review.md exits 2 and never starts codex"
else
  failc "W2" "wrapper" "rc=$rc started=$([ -e "$WORK/w2.prompt" ] && echo yes || echo no)"
fi

TOTAL=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))
echo ""
echo "RESULT: $PASS_COUNT passed, $FAIL_COUNT failed, $SKIP_COUNT skipped (of $TOTAL checks)"
[ "$FAIL_COUNT" -eq 0 ]
