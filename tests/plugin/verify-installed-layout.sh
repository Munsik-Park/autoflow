#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
# =============================================================================
# Test: the plugin as installed — hook helpers and rule citations resolve from
# the installed plugin root (issue #454 PR-3, ADR-0027 D1/D3)
# =============================================================================
# Reproduces the real install layout: the plugin package — this repository's
# tree, copied the way an install copies it (tests/lib/plugin-package.sh) — at
# <config>/plugins/cache/autoflow/autoflow/<version>/, CLAUDE_PLUGIN_ROOT naming
# that copy, and an unstamped target: a git repository with no scripts/, no
# docs/ and no AutoFlow file of its own, the working directory of every run.
# No other AutoFlow checkout is on any path a run consults. Plain bash +
# jq/git/tar/grep/awk (no bats, no node/npm).
#
# Legs (category: packaging):
#
#   I   the gate hook's advisories find their helpers through the plugin root
#     I1  ledger advisory: the installed ledger-entry-id.sh runs and the
#         warning names it at the installed location
#     I2  spawn-policy advisory against the target's own policy: the installed
#         readout runs and compares against the target's policy
#     I3  spawn-policy advisory where the target has no policy: the installed
#         default policy answers
#
#   R   rule citations resolve to the installed location
#     R1  every `$(af_path <rel>)` the gate hook names exists in the installed
#         copy, and each `> Section` cited after it is a heading or a labelled
#         item of that document; no hook message names a bare docs/ or
#         scripts/ path
#     R2  the denies the hook emits from the installed copy (issue filing,
#         a model-less spawn, a backgrounded suite run, a merge during a
#         cycle, a ledger rewrite) name only installed paths that exist, and
#         their cited sections resolve
#     R3  the read-dedup hook's citation of the core resolves in the installed
#         copy
#     R4  every agent definition, with ${CLAUDE_PLUGIN_ROOT} substituted as the
#         harness substitutes it in an agent body, declares the installed root
#         and every `<autoflow-root>/…` path and `> Section` it cites resolves
#         there; every generated command body's paths resolve there as well
#     R5  `autoflow-root` (bin/) prints the installed root
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../lib/plugin-package.sh
. "$REPO_ROOT/tests/lib/plugin-package.sh"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
pass()  { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
failc() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s -- %s\n' "$1" "$2"; }

for _tool in jq git tar; do
  command -v "$_tool" >/dev/null 2>&1 || { echo "verify-installed-layout: $_tool is required" >&2; exit 2; }
done

WORK="$(mktemp -d)"
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT

CFG="$WORK/config"
ROOT="$(install_plugin_package "$REPO_ROOT" "$CFG")" || { echo "verify-installed-layout: package copy failed" >&2; exit 2; }
HOOK="$ROOT/hooks/check-autoflow-gate.sh"
DEDUP="$ROOT/hooks/check-read-dedup.sh"

# run_hook <target> <hook> — the hook as the harness runs it: CLAUDE_PLUGIN_ROOT
# the installed copy, CLAUDE_PROJECT_DIR and the working directory the target,
# the developer's own session variables cleared.
# HOME is a scratch directory, so the record root (its default, HOME/.autoflow —
# scripts/lib/records.sh) and the user file are the test's own, never the
# operator's.
TEST_HOME="$WORK/home"
mkdir -p "$TEST_HOME"
run_hook() {
  (cd "$1" && env -u AUTOFLOW_SPAWN_POLICY HOME="$TEST_HOME" \
    CLAUDE_CONFIG_DIR="$CFG" CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PROJECT_DIR="$1" bash "$2")
}
# attempt_dir <checkout> <key> — make an attempt's record directory owned by
# <checkout> under the test's record root, and print it.
# shellcheck source=../../scripts/lib/records.sh
. "$ROOT/scripts/lib/records.sh"
attempt_dir() {
  local _a="$TEST_HOME/.autoflow/$(autoflow_repo_key "$1")/$2"
  mkdir -p "$_a" && printf '%s\n' "$1" > "$_a/checkout" && printf '%s' "$_a"
}

git_init() {
  mkdir -p "$1"
  ( cd "$1" && git init -q \
    && git -c user.email=test@example.com -c user.name=test commit -q --allow-empty -m init )
}

bash_payload()  { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(printf '%s' "$1" | jq -Rs .)"; }
agent_payload() { printf '{"tool_name":"Agent","tool_input":{"subagent_type":"%s","model":"%s","prompt":"x"}}' "$1" "$2"; }

# section_resolves <file> <cited> — the section a citation names after
# "<path> > " is a heading or a labelled item (**Label**, *Label*) of <file>:
# the cited text starts with the name, or the name with the cited text, at a
# word boundary. The cited text runs on into prose where no bracket closes it,
# so the name is matched as its prefix.
section_resolves() {
  [ -f "$1" ] || return 1
  awk -v s="$2" '
    function norm(x) { gsub(/[*`]/, "", x); sub(/^\[(MUST|DENY)\] /, "", x); gsub(/^[ \t]+|[ \t:]+$/, "", x); return x }
    function pre(a, b,   c) {
      if (b == "" || index(a, b) != 1) return 0
      c = substr(a, length(b) + 1, 1)
      return c == "" || c !~ /[A-Za-z0-9]/
    }
    function hit(x) { x = norm(x); return pre(s, x) || pre(x, s) }
    BEGIN { s = norm(s); if (s == "") exit 1 }
    /^#+ / { h = $0; sub(/^#+ +/, "", h); if (hit(h)) { f = 1; exit } }
    {
      l = $0
      while (match(l, /\*\*[^*]+\*\*/)) { if (hit(substr(l, RSTART + 2, RLENGTH - 4))) { f = 1; exit }; l = substr(l, RSTART + RLENGTH) }
      l = $0
      while (match(l, /(^|[^*])\*[^* ][^*]*\*/)) { x = substr(l, RSTART, RLENGTH); sub(/^[^*]?\*/, "", x); if (hit(x)) { f = 1; exit }; l = substr(l, RSTART + RLENGTH) }
    }
    END { exit !f }' "$1"
}

# path_exists <path> — <path> or, with its placeholders (<x>, {x}, …) read as
# wildcards, some file it names exists.
path_exists() {
  local _g
  _g=$(printf '%s' "$1" | sed -E -e 's/<[^>]*>/*/g' -e 's/\{[^}]*\}/*/g' -e 's/…/*/g')
  compgen -G "${_g%/}" >/dev/null
}

# check_citations <label> <text> — every installed path in <text> exists, and
# the first section cited after it ("<path> > <Section>") resolves.
# Prints one line per defect.
check_citations() {
  local _t="$2" _p _s
  while IFS= read -r _p; do
    [ -n "$_p" ] || continue
    path_exists "$_p" || printf '%s: missing %s\n' "$1" "$_p"
  done < <(printf '%s' "$_t" | grep -oE "$ROOT/[^ )\`'\";,]*" | sed 's/[.:]*$//' | sort -u)
  while IFS='|' read -r _p _s; do
    [ -n "$_p" ] || continue
    section_resolves "$_p" "$_s" || printf '%s: %s > %s does not resolve\n' "$1" "${_p#"$ROOT"/}" "$_s"
  done < <(printf '%s' "$_t" | grep -oE "$ROOT/[^ )\`'\";,]+\`? > [^>);.,]+" \
             | sed -E "s/\`? > /|/; s/ +$//")
}

# ── I: advisories find their helpers through the plugin root ─────────────────
echo "== I: the hook's advisories find their helpers through the plugin root =="

T="$WORK/target"
git_init "$T"
A1="$(attempt_dir "$T" 2026-01-01-000000-issue-1)"
printf '# ledger\n\n## no identifier here\n' > "$A1/issue-1-ledger.md"
mkdir -p "$T/.claude/autoflow"
jq '.phases |= with_entries(if .value.agent_type == "autoflow-evaluator" then .value.model = "haiku" else . end)' \
  "$ROOT/.claude/autoflow/spawn-policy.json" > "$T/.claude/autoflow/spawn-policy.json"
if [ -e "$T/scripts" ] || [ -e "$T/docs" ] || [ -e "$T/.claude/autoflow/manifest.json" ]; then
  failc "I0" "the target is not unstamped"
fi

out=$(bash_payload ls | run_hook "$T" "$HOOK" 2>"$WORK/i1.err"); rc=$?
if [ "$rc" -eq 0 ] && grep -q 'decision-ledger identifier defect' "$WORK/i1.err" \
   && printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | test("identifier defect")' >/dev/null 2>&1 \
   && grep -qF "$ROOT/scripts/ledger/ledger-entry-id.sh next" "$WORK/i1.err"; then
  pass "I1: the ledger advisory runs the installed helper and names it at $ROOT/scripts/ledger/"
else
  failc "I1" "rc=$rc stderr=$(head -c 400 "$WORK/i1.err")"
fi

agent_payload autoflow-evaluator opus | run_hook "$T" "$HOOK" >/dev/null 2>"$WORK/i2.err"; rc=$?
if [ "$rc" -eq 0 ] && grep -q "outside the spawn policy's admitted set" "$WORK/i2.err" \
   && grep -q 'Admitted: haiku' "$WORK/i2.err" \
   && grep -qF "$ROOT/scripts/spawn-policy/spawn-policy.sh model <phase-key>" "$WORK/i2.err"; then
  pass "I2: the spawn-policy advisory runs the installed readout against the target's own policy"
else
  failc "I2" "rc=$rc stderr=$(head -c 400 "$WORK/i2.err")"
fi

TN="$WORK/target-nopolicy"
git_init "$TN"
want=$(jq -r '[.phases[] | select(.agent_type == "autoflow-evaluator") | .model] | unique | join(" ")' \
  "$ROOT/.claude/autoflow/spawn-policy.json")
agent_payload autoflow-evaluator no-such-model | run_hook "$TN" "$HOOK" >/dev/null 2>"$WORK/i3.err"; rc=$?
if [ "$rc" -eq 0 ] && grep -q "outside the spawn policy's admitted set" "$WORK/i3.err" \
   && grep -qF "Admitted: $want" "$WORK/i3.err" && ! grep -q 'Admitted: haiku' "$WORK/i3.err"; then
  pass "I3: with no target policy, the installed default policy answers (admitted: $want)"
else
  failc "I3" "rc=$rc want='$want' stderr=$(head -c 400 "$WORK/i3.err")"
fi

# ── R: rule citations resolve to the installed location ──────────────────────
echo "== R: rule citations resolve to the installed location =="

r1=""
nref=0
while IFS='|' read -r _rel _sec; do
  [ -n "$_rel" ] || continue
  nref=$((nref + 1))
  [ -e "$ROOT/$_rel" ] || { r1="$r1 missing:$_rel"; continue; }
  [ -z "$_sec" ] || section_resolves "$ROOT/$_rel" "$_sec" || r1="$r1 section:$_rel>$_sec"
done < <(grep -oE '\$\(af_path [^)]+\)( > [^>);."]+)?' "$HOOK" \
           | sed -E 's/^\$\(af_path ([^)]+)\)( > )?/\1|/; s/ +$//' | sort -u)
bare_msgs=$(grep -nE '^[[:space:]]*(echo|printf|REMINDER=)' "$HOOK" "$DEDUP" \
  | grep -vE 'af_path|\$\{CORE\}' | grep -E '(^|[ (`])(docs|scripts)/[a-z]' || true)
if [ "$nref" -eq 0 ]; then
  failc "R1" "no af_path citation found in the hook (vacuous)"
elif [ -z "$r1" ] && [ -z "$bare_msgs" ]; then
  pass "R1: all $nref af_path citations in the installed hook resolve, sections included; no message names a bare AutoFlow path"
else
  failc "R1" "unresolved:$r1 bare:$(printf '%s' "$bare_msgs" | head -c 300)"
fi

# R2 — denies emitted by the installed hook. The merge deny needs a cycle in
# flight, so it runs in its own target with an active state file.
TA="$WORK/target-active"
git_init "$TA"
A2="$(attempt_dir "$TA" 2026-10-17-000000-issue-2)"
jq -n '{active:true, issue:"#2", title:"t", date:"2026-10-17", branch:"dev/2026-10-17-000000-issue-2",
        cycle:1, mode:"new-issue", phase:"in-progress",
        phases:{gate_hypothesis:{evaluator:"", scores:{}, verdict:"pending"},
                gate_plan:{evaluator:"", scores:{}}, audit:{evaluator:"", scores:{}},
                gate_quality:{evaluator:"", scores:{}}}}' > "$A2/issue-2.json"
LEDGER="$A1/issue-1-ledger.md"
r2=""; msgs=""
deny_case() {  # <name> <target> <payload> <expected stderr fragment>
  local _err="$WORK/r2-$1.err" _rc
  printf '%s' "$3" | run_hook "$2" "$HOOK" >/dev/null 2>"$_err"; _rc=$?
  if [ "$_rc" -ne 2 ] || ! grep -qF "$4" "$_err"; then
    r2="$r2 [$1: rc=$_rc $(head -c 200 "$_err")]"
  fi
  msgs="$msgs$(cat "$_err")"$'\n'
}
deny_case issue    "$T"  "$(bash_payload 'gh issue create --title x')" "$ROOT/docs/issue-proposal.md"
deny_case nomodel  "$T"  '{"tool_name":"Agent","tool_input":{"subagent_type":"autoflow-evaluator","prompt":"x"}}' "$ROOT/docs/core.md > Spawn Model"
deny_case suites   "$T"  "$(bash_payload 'nohup bash scripts/test/run-suites.sh --all')" "$ROOT/docs/role-common-rules.md > Bash Execution Mode"
deny_case merge    "$TA" "$(bash_payload 'gh pr merge 7')" "$ROOT/docs/core.md > Push and PR creation"
deny_case ledger   "$T"  "$(jq -n --arg f "$LEDGER" '{tool_name:"Edit",tool_input:{file_path:$f,old_string:"## no identifier here",new_string:"## rewritten"}}')" "$ROOT/docs/decision-ledger.md"
bad=$(check_citations R2 "$msgs")
leaked=$(printf '%s' "$msgs" | grep -oE '(^|[ (])(docs|scripts)/[a-z][^ )]*' || true)
if [ -z "$r2" ] && [ -z "$bad" ] && [ -z "$leaked" ]; then
  pass "R2: five denies from the installed hook name only installed paths that exist, and their sections resolve"
else
  failc "R2" "cases:$r2 citations:$bad bare:$leaked"
fi

stub='{"tool_name":"Read","tool_input":{"file_path":"/x/y.md"},"tool_response":"File unchanged since last read"}'
dout=$(printf '%s' "$stub" | run_hook "$T" "$DEDUP" 2>/dev/null)
dctx=$(printf '%s' "$dout" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
dbad=$(check_citations R3 "$dctx")
if printf '%s' "$dctx" | grep -qF "$ROOT/docs/core.md > Execution Principles > Incomplete output is never ground truth" \
   && [ -z "$dbad" ] && section_resolves "$ROOT/docs/core.md" 'Incomplete output is never ground truth'; then
  pass "R3: the read-dedup reminder cites the installed core, and the section resolves"
else
  failc "R3" "ctx=$(printf '%s' "$dctx" | head -c 200) defects=$dbad"
fi

r4=""; nagents=0
for _a in "$ROOT"/agents/*.md; do
  nagents=$((nagents + 1))
  # The harness substitutes ${CLAUDE_PLUGIN_ROOT} in an agent body (issue #454,
  # measurement M1); the declaration then names the installed root, and
  # `<autoflow-root>` reads as that root.
  body=$(sed "s|\${CLAUDE_PLUGIN_ROOT}|$ROOT|g" "$_a")
  printf '%s\n' "$body" | grep -qxF "AutoFlow root (\`<autoflow-root>\`): $ROOT" || r4="$r4 nodecl:${_a##*/}"
  r4="$r4$(check_citations "${_a##*/}" "$(printf '%s' "$body" | tr '\n' ' ' | sed -E 's/ +/ /g' | sed "s|<autoflow-root>/|$ROOT/|g")" | tr '\n' ' ')"
done
for _s in $(bash "$ROOT/scripts/skills/gen-skill-bodies.sh" --list | sed -e 's|^skills/||' -e 's|/SKILL.md$||'); do
  body=$(sed "s|<autoflow-root>/|$ROOT/|g" "$ROOT/skills/$_s/SKILL.md")
  r4="$r4$(printf '%s' "$body" | grep -oE "$ROOT/[^] \`'\"),;|]*" | sed 's/[.:]*$//' | sort -u \
    | while IFS= read -r _p; do
        _g=$(printf '%s' "$_p" | sed -E -e 's/<[^>]*>/*/g' -e 's/\{[^}]*\}/*/g' -e 's/…/*/g')
        compgen -G "${_g%/}" >/dev/null || printf ' %s:missing:%s' "$_s" "${_p#"$ROOT"/}"
      done)"
done
if [ "$nagents" -lt 10 ]; then
  failc "R4" "only $nagents agent definitions in the installed copy"
elif [ -z "$(printf '%s' "$r4" | tr -d ' ')" ]; then
  pass "R4: $nagents agent definitions declare the installed root and their citations resolve there; so do the command bodies' paths"
else
  failc "R4" "$r4"
fi

got=$(cd "$T" && "$ROOT/bin/autoflow-root")
if [ "$got" = "$ROOT" ]; then
  pass "R5: autoflow-root prints the installed root"
else
  failc "R5" "printed '$got', want '$ROOT'"
fi

# R6 — non-vacuity of the citation reader R2–R4 rely on.
spec=$(check_citations R6 "see ($ROOT/docs/core.md > Spawn Model) and ($ROOT/docs/core.md > No Such Section) and $ROOT/docs/no-such-file.md")
if printf '%s' "$spec" | grep -qF 'docs/core.md > No Such Section does not resolve' \
   && printf '%s' "$spec" | grep -qF "missing $ROOT/docs/no-such-file.md" \
   && ! printf '%s' "$spec" | grep -qF 'Spawn Model'; then
  pass "R6: the citation reader flags an unknown section and a missing file, and accepts a real section"
else
  failc "R6" "reader output: $spec"
fi

TOTAL=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))
echo ""
echo "RESULT: $PASS_COUNT passed, $FAIL_COUNT failed, $SKIP_COUNT skipped (of $TOTAL checks)"
[ "$FAIL_COUNT" -eq 0 ]
