#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: setup/thin-root-layer/drift-check.sh scripts/spawn-policy/spawn-policy.sh plugin/autoflow/skills/install/scripts/detect.sh plugin/autoflow/skills/install/SKILL.md .claude/autoflow/spawn-policy.json setup/manifest.json setup/SETUP-GUIDE.md docs/tool-delivery-contract.md docs/autoflow-guide.md
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: issue #185 — drift-check D6: a stale spawn-policy scaffold is named
#       where drift-check already runs (install Step 1 / Step 4, PREFLIGHT),
#       instead of surfacing as a fail-closed readout at ARCHITECT.
# =============================================================================
# Subjects:
#   setup/thin-root-layer/drift-check.sh — D6: `spawn-policy.sh check` over the
#                                         target's scaffold against the loaded
#                                         agent definitions, plus the row set
#                                         against the marketplace clone's sample
#   scripts/spawn-policy/spawn-policy.sh — the readout D6 executes (its own
#                                         tree's copy, never the target's)
#   plugin/autoflow/skills/install/scripts/detect.sh — D6 filtered out of DRIFT
#                                         (not stamp-repairable) and reported on
#                                         the POLICY_* axis
#   plugin/autoflow/skills/install/SKILL.md — Step 1 / Step 4 report the axis
#
# Every leg runs under a HERMETIC $CLAUDE_CONFIG_DIR with CLAUDE_PLUGIN_ROOT /
# AUTOFLOW_MARKETPLACE_ROOT unset unless the leg sets them, so a developer
# machine's real plugin cache never satisfies a verdict.
#
# Cases (AC = the issue's acceptance criteria):
#   D6-PASS               AC3: a scaffold equal to the sample, definitions from
#                         the plugin -> PASS: D6, no FAIL: D6, exit 0
#   D6-EFFORT             AC1: a phase row's effort != the definition's
#                         frontmatter -> FAIL: D6 naming the row's agent type,
#                         the definition file and both values; exit 1; HINT
#                         names the scaffold path
#   D6-MISSING-NEW-TYPE   AC2: the row for a shipped definition is absent ->
#                         FAIL: D6 (definition unnamed) AND FAIL: D6 naming the
#                         missing row from the sample
#   D6-MISSING-SAME-TYPE  AC2 (issue #179 class): a required row whose agent
#                         type another row already uses is absent -> `check`
#                         alone is silent; the sample comparison names the row
#   D6-MISSING-SITE       AC2: a required workflow_sites row is absent -> FAIL
#   D6-AGENT-TYPE         a row naming an agent_type the current version
#                         renamed -> FAIL naming both types
#   D6-LEVERS             a model value, a workflow_sites effort, an extra row
#                         -> not findings; PASS: D6
#   D6-TREE-DEFS          a target carrying its own .claude/agents is checked
#                         against those, no plugin needed
#   D6-SKIP-DEFS          AC4: no definitions resolvable -> SKIP: D6 naming
#                         every location tried; exit 0
#   D6-SKIP-READOUT       AC4: the readout is absent beside the detector ->
#                         SKIP: D6 naming the path tried
#   D6-SKIP-SCAFFOLD      AC4: no scaffold in the target -> SKIP: D6 naming it
#   D6-SKIP-CLONE         no clone -> `check` verdict still produced; the
#                         required-row comparison SKIPs naming D4
#   D6-CLONE-NO-SAMPLE    a clone without a sample -> the comparison SKIPs
#   ORACLE-NO-TARGET-CODE the cache oracle never executes the target's
#                         scripts/spawn-policy/spawn-policy.sh (a marker-
#                         writing target copy leaves no marker; D1 reports it;
#                         D6 still evaluates with the oracle's own readout)
#   TIMING                AC7: the D6 leg adds < 1 s to a drift-check run
#   DET-*                 AC5 seam: detect.sh DRIFT_STATE unaffected by D6;
#                         POLICY_STATE / POLICY_FAILS / POLICY_FINDING carry it;
#                         a `PASS: D6` beside a `SKIP: D6` aggregates to skip,
#                         and every skip reason is carried on POLICY_SKIP
#                         (PR #186 review, Medium); a `FAIL: D6` beside a
#                         `SKIP: D6` keeps both field kinds (review, Low)
#   SKILL-*               AC5: SKILL.md Step 1 reads the POLICY axis; Step 4
#                         reports the D6 lines with the rows to fix
#   DOC-*                 drift-check header, SETUP-GUIDE, tool-delivery-
#                         contract, autoflow-guide PREFLIGHT name D6
#   MAN-ROW               setup/manifest.json carries the current detector hash
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DRIFT_SRC="$REPO_ROOT/setup/thin-root-layer/drift-check.sh"
READOUT="$REPO_ROOT/scripts/spawn-policy/spawn-policy.sh"
DETECT_SH="$REPO_ROOT/plugin/autoflow/skills/install/scripts/detect.sh"
SKILL_MD="$REPO_ROOT/plugin/autoflow/skills/install/SKILL.md"
INIT_SH="$REPO_ROOT/setup/init.sh"
MANIFEST="$REPO_ROOT/setup/manifest.json"
PLUGIN_DIR="$REPO_ROOT/plugin/autoflow"
SAMPLE="$REPO_ROOT/.claude/autoflow/spawn-policy.json"

PASS=0; FAIL=0
pass()  { echo "  PASS: $1"; PASS=$((PASS + 1)); }
failc() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT INT TERM

export CLAUDE_CONFIG_DIR="$WORK/empty-config"
mkdir -p "$CLAUDE_CONFIG_DIR"
unset CLAUDE_PLUGIN_ROOT AUTOFLOW_MARKETPLACE_ROOT

stamp() { mkdir -p "$1"; bash "$INIT_SH" --target "$1" >/dev/null 2>&1; }

# run_drift <target> [VAR=value ...] — the installed detector; sets DRIFT_OUT / DRIFT_RC.
run_drift() {
  local t="$1"; shift
  DRIFT_OUT=$(env CLAUDE_PROJECT_DIR="$t" "$@" sh "$t/.claude/autoflow/drift-check.sh" 2>&1)
  DRIFT_RC=$?
}
d6_lines() { printf '%s\n' "$DRIFT_OUT" | grep -E '^(PASS|FAIL|SKIP|HINT): D6' ; }
has()      { printf '%s\n' "$DRIFT_OUT" | grep -qF -- "$1"; }
first_d6() { d6_lines | head -3 | tr '\n' ' ' | cut -c1-300; }

# set_policy <target> <jq-filter> — rewrite the target's scaffold from the sample.
set_policy() { jq "$2" "$SAMPLE" > "$1/.claude/autoflow/spawn-policy.json"; }

# Full resolution: definitions from the plugin, sample from the clone.
FULL=(CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" AUTOFLOW_MARKETPLACE_ROOT="$REPO_ROOT")

echo "=== Issue #185 — drift-check D6: spawn-policy scaffold vs loaded definitions ==="

T="$WORK/target"; stamp "$T"
if [ ! -f "$T/.claude/autoflow/drift-check.sh" ] || [ ! -f "$T/scripts/spawn-policy/spawn-policy.sh" ] || [ ! -f "$T/.claude/autoflow/spawn-policy.json" ]; then
  failc "SETUP: stamp into $T did not deliver drift-check.sh + spawn-policy.sh + the scaffold"
  echo "PASS: $PASS  FAIL: $FAIL"; exit 1
fi

# -----------------------------------------------------------------------------
echo "== D6 verdicts on the installed detector =="
# -----------------------------------------------------------------------------
run_drift "$T" "${FULL[@]}"
if [ "$DRIFT_RC" -eq 0 ] && has "PASS: D6: spawn-policy scaffold ($T/.claude/autoflow/spawn-policy.json) agrees with the loaded agent definitions ($PLUGIN_DIR/agents)" \
   && ! has "FAIL: D6"; then
  pass "D6-PASS: a scaffold equal to the sample PASSes D6 against the plugin's definitions (exit 0)"
else
  failc "D6-PASS: rc=$DRIFT_RC; $(first_d6)"
fi

set_policy "$T" '.phases.red.effort = "high"'
run_drift "$T" "${FULL[@]}"
if [ "$DRIFT_RC" -ne 0 ] \
   && has "FAIL: D6 -- phases rows for agent_type 'autoflow-tester' declare effort 'high', but the loaded definition $PLUGIN_DIR/agents/autoflow-tester.md carries 'effort: xhigh'" \
   && printf '%s\n' "$DRIFT_OUT" | grep '^HINT: D6' | grep -qF "$T/.claude/autoflow/spawn-policy.json"; then
  pass "D6-EFFORT: an effort that differs from the definition's frontmatter is a FAIL: D6 naming the row's agent type, the definition file and both values (exit $DRIFT_RC); the HINT names the scaffold"
else
  failc "D6-EFFORT: rc=$DRIFT_RC; $(first_d6)"
fi

set_policy "$T" 'del(.phases["diagnose-loopcheck"])'
run_drift "$T" "${FULL[@]}"
if [ "$DRIFT_RC" -ne 0 ] \
   && has "FAIL: D6 -- agent definition 'autoflow-loopcheck' is neither named by a phases row nor declared unmapped" \
   && has "FAIL: D6 -- missing phases row 'diagnose-loopcheck' (agent_type autoflow-loopcheck, effort high)"; then
  pass "D6-MISSING-NEW-TYPE: the row for a shipped definition absent -> FAIL: D6 from the membership rule AND FAIL: D6 naming the missing row from the sample"
else
  failc "D6-MISSING-NEW-TYPE: rc=$DRIFT_RC; $(first_d6)"
fi

set_policy "$T" 'del(.phases["architect-dev-participant"])'
_chk=$(cd / && CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" AUTOFLOW_SPAWN_POLICY="$T/.claude/autoflow/spawn-policy.json" bash "$READOUT" check 2>&1); _chk_rc=$?
run_drift "$T" "${FULL[@]}"
if [ "$_chk_rc" -eq 0 ] && [ "$DRIFT_RC" -ne 0 ] \
   && has "FAIL: D6 -- missing phases row 'architect-dev-participant' (agent_type autoflow-planner, effort xhigh) — required by the current version"; then
  pass "D6-MISSING-SAME-TYPE: a required row whose agent type another row uses is invisible to \`check\` (exit 0) and named by the sample comparison (the issue #179 class that failed closed at ARCHITECT)"
else
  failc "D6-MISSING-SAME-TYPE: check rc=$_chk_rc ('$_chk'); drift rc=$DRIFT_RC; $(first_d6)"
fi

set_policy "$T" 'del(.workflow_sites["architect-deliberation"].ledger)'
run_drift "$T" "${FULL[@]}"
if [ "$DRIFT_RC" -ne 0 ] && has "FAIL: D6 -- missing workflow_sites row 'architect-deliberation.ledger' — required by the current version (the workflow fails closed without it)"; then
  pass "D6-MISSING-SITE: a required workflow_sites row absent -> FAIL: D6 naming it"
else
  failc "D6-MISSING-SITE: rc=$DRIFT_RC; $(first_d6)"
fi

set_policy "$T" '.phases["diagnose-loopcheck"].agent_type = "Explore" | .phases["diagnose-loopcheck"].effort = "inherit"'
run_drift "$T" "${FULL[@]}"
if [ "$DRIFT_RC" -ne 0 ] && has "FAIL: D6 -- phases row 'diagnose-loopcheck' names agent_type 'Explore', but the current version names 'autoflow-loopcheck'"; then
  pass "D6-AGENT-TYPE: a row still naming the pre-#180 research type is a FAIL: D6 naming both agent types"
else
  failc "D6-AGENT-TYPE: rc=$DRIFT_RC; $(first_d6)"
fi

set_policy "$T" '.phases.green.model = "haiku" | .workflow_sites["architect-deliberation"].ledger.effort = "high" | .phases["target-extra"] = {agent_type: "autoflow-analyzer", model: "sonnet", effort: "high", work_type: "target-added row"}'
run_drift "$T" "${FULL[@]}"
if [ "$DRIFT_RC" -eq 0 ] && has "PASS: D6" && ! has "FAIL: D6"; then
  pass "D6-LEVERS: a model value, a workflow_sites effort and a target-added row are the target's own — PASS: D6"
else
  failc "D6-LEVERS: rc=$DRIFT_RC; $(first_d6)"
fi
set_policy "$T" '.'

# A target that carries its own definitions is checked against those.
mkdir -p "$T/.claude/agents"; cp "$PLUGIN_DIR"/agents/autoflow-*.md "$T/.claude/agents/"
run_drift "$T" AUTOFLOW_MARKETPLACE_ROOT="$REPO_ROOT"
if has "PASS: D6: spawn-policy scaffold ($T/.claude/autoflow/spawn-policy.json) agrees with the loaded agent definitions ($T/.claude/agents)"; then
  pass "D6-TREE-DEFS: a target carrying .claude/agents/autoflow-*.md is checked against its own copies, no plugin resolution needed"
else
  failc "D6-TREE-DEFS: $(first_d6)"
fi
rm -rf "$T/.claude/agents"

# -----------------------------------------------------------------------------
echo "== D6 SKIP arms (AC4) =="
# -----------------------------------------------------------------------------
run_drift "$T"
if [ "$DRIFT_RC" -eq 0 ] && printf '%s\n' "$DRIFT_OUT" | grep '^SKIP: D6 -- agent definitions not locally resolvable (tried: ' \
     | grep -F "$T/.claude/agents" | grep -F 'installed_plugins.json' | grep -qF 'plugins/cache/autoflow/autoflow/<version>/agents'; then
  pass "D6-SKIP-DEFS: with no definitions resolvable D6 SKIPs (exit $DRIFT_RC), naming the target's agents dir, the registry and the cache path"
else
  failc "D6-SKIP-DEFS: rc=$DRIFT_RC; $(first_d6)"
fi

mv "$T/scripts/spawn-policy/spawn-policy.sh" "$WORK/readout.bak"
run_drift "$T" "${FULL[@]}"
if has "SKIP: D6 -- spawn-policy readout not found beside this script (tried: $T/.claude/autoflow/../../scripts/spawn-policy/spawn-policy.sh)" && ! has "FAIL: D6"; then
  pass "D6-SKIP-READOUT: the readout absent beside the detector -> SKIP: D6 naming the path tried (D1 owns the missing copy)"
else
  failc "D6-SKIP-READOUT: $(first_d6)"
fi
mv "$WORK/readout.bak" "$T/scripts/spawn-policy/spawn-policy.sh"

mv "$T/.claude/autoflow/spawn-policy.json" "$WORK/policy.bak"
run_drift "$T" "${FULL[@]}"
if has "SKIP: D6 -- target carries no .claude/autoflow/spawn-policy.json (tried: $T/.claude/autoflow/spawn-policy.json" && ! has "FAIL: D6" \
   && has "FAIL: D1 -- scaffolded file missing: .claude/autoflow/spawn-policy.json"; then
  pass "D6-SKIP-SCAFFOLD: no scaffold -> SKIP: D6 naming it; D1 carries the FAIL"
else
  failc "D6-SKIP-SCAFFOLD: $(first_d6)"
fi
mv "$WORK/policy.bak" "$T/.claude/autoflow/spawn-policy.json"

run_drift "$T" CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR"
if has "PASS: D6" && has "SKIP: D6 -- required-row comparison deferred (marketplace clone not locally resolvable — see D4)"; then
  pass "D6-SKIP-CLONE: with no clone the \`check\` verdict is still produced and the required-row comparison SKIPs naming D4"
else
  failc "D6-SKIP-CLONE: $(first_d6)"
fi

C1="$WORK/clone-no-sample"; mkdir -p "$C1/setup" "$C1/.claude-plugin"
cp "$MANIFEST" "$C1/setup/manifest.json"; cp "$REPO_ROOT/.claude-plugin/marketplace.json" "$C1/.claude-plugin/"
run_drift "$T" CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" AUTOFLOW_MARKETPLACE_ROOT="$C1"
if has "PASS: D6" && has "SKIP: D6 -- required-row comparison deferred (marketplace clone at $C1 carries no .claude/autoflow/spawn-policy.json sample)"; then
  pass "D6-CLONE-NO-SAMPLE: a clone without a sample -> the comparison SKIPs naming the clone, never a FAIL"
else
  failc "D6-CLONE-NO-SAMPLE: $(first_d6)"
fi

# -----------------------------------------------------------------------------
echo "== TRUST: the cache oracle never executes the target's readout =="
# -----------------------------------------------------------------------------
TT="$WORK/target-tampered"; stamp "$TT"
printf '#!/usr/bin/env bash\n: > "%s/PWNED_MARKER"\nexit 0\n' "$TT" > "$TT/scripts/spawn-policy/spawn-policy.sh"
out=$(env CLAUDE_PROJECT_DIR="$TT" "${FULL[@]}" sh "$DRIFT_SRC" 2>&1); rc=$?
if [ ! -e "$TT/PWNED_MARKER" ] && [ "$rc" -ne 0 ] \
   && printf '%s\n' "$out" | grep -q '^FAIL: D1 -- content drift: scripts/spawn-policy/spawn-policy.sh' \
   && printf '%s\n' "$out" | grep -q '^PASS: D6'; then
  pass "ORACLE-NO-TARGET-CODE: the source-tree oracle leaves no marker (the target's readout was not executed), D1 flags it, and D6 still evaluates with the oracle's own readout"
else
  failc "ORACLE-NO-TARGET-CODE (oracle): marker=$([ -e "$TT/PWNED_MARKER" ] && echo CREATED || echo absent) rc=$rc; $(printf '%s\n' "$out" | grep -E ': D[16]' | head -3 | tr '\n' ' ')"
fi
rm -f "$TT/PWNED_MARKER"
out=$(env TARGET_ROOT="$TT" PLUGIN_CACHE_ROOT="$REPO_ROOT" CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" sh "$DETECT_SH" 2>&1)
if [ ! -e "$TT/PWNED_MARKER" ] && printf '%s\n' "$out" | grep -q '^POLICY_STATE=pass$' && printf '%s\n' "$out" | grep -q '^DRIFT_STATE=drift$'; then
  pass "ORACLE-NO-TARGET-CODE: detect.sh leaves no marker either, reports the tampered copy as drift and the scaffold as POLICY_STATE=pass"
else
  failc "ORACLE-NO-TARGET-CODE (detect): marker=$([ -e "$TT/PWNED_MARKER" ] && echo CREATED || echo absent); $(printf '%s\n' "$out" | grep -E '^(DRIFT_STATE|POLICY_STATE)' | tr '\n' ' ')"
fi

# -----------------------------------------------------------------------------
echo "== TIMING (AC7): the D6 leg adds < 1 s =="
# -----------------------------------------------------------------------------
now_ms() { perl -MTime::HiRes=time -e 'printf "%d\n", time * 1000'; }
t0=$(now_ms); run_drift "$T" "${FULL[@]}"; t1=$(now_ms)
mv "$T/scripts/spawn-policy/spawn-policy.sh" "$WORK/readout.bak"
t2=$(now_ms); run_drift "$T" "${FULL[@]}"; t3=$(now_ms)
mv "$WORK/readout.bak" "$T/scripts/spawn-policy/spawn-policy.sh"
delta=$(( (t1 - t0) - (t3 - t2) ))
if [ "$delta" -lt 1000 ]; then
  pass "TIMING: D6 adds ${delta} ms to a drift-check run (full $((t1 - t0)) ms vs readout-absent $((t3 - t2)) ms) — under the 1 s bound"
else
  failc "TIMING: D6 adds ${delta} ms (full $((t1 - t0)) ms vs readout-absent $((t3 - t2)) ms) — over the 1 s bound"
fi

# -----------------------------------------------------------------------------
echo "== DET: detect.sh reports D6 on the POLICY axis, never as DRIFT =="
# -----------------------------------------------------------------------------
kv() { printf '%s\n' "$1" | sed -n "s/^$2=//p" | head -1; }
set_policy "$T" '.phases.red.effort = "high" | del(.phases["architect-dev-participant"])'
out=$(env TARGET_ROOT="$T" PLUGIN_CACHE_ROOT="$REPO_ROOT" CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" sh "$DETECT_SH" 2>&1)
nf=$(printf '%s\n' "$out" | grep -c '^POLICY_FINDING=')
if [ "$(kv "$out" DRIFT_STATE)" = "clean" ] && [ "$(kv "$out" DRIFT_FAILS)" = "0" ] \
   && [ "$(kv "$out" POLICY_STATE)" = "fail" ] && [ "$(kv "$out" POLICY_FAILS)" = "$nf" ] && [ "$nf" -ge 2 ] \
   && printf '%s\n' "$out" | grep '^POLICY_FINDING=' | grep -q "agent_type 'autoflow-tester' declare effort 'high'" \
   && printf '%s\n' "$out" | grep '^POLICY_FINDING=' | grep -q "missing phases row 'architect-dev-participant'"; then
  pass "DET-D6-FAIL: a stale scaffold is DRIFT_STATE=clean (not stamp-repairable) with POLICY_STATE=fail, POLICY_FAILS=$nf and one POLICY_FINDING per row to fix"
else
  failc "DET-D6-FAIL: $(printf '%s\n' "$out" | grep -E '^(DRIFT_STATE|DRIFT_FAILS|POLICY_)' | tr '\n' ' ' | cut -c1-400)"
fi
set_policy "$T" '.'
out=$(env TARGET_ROOT="$T" PLUGIN_CACHE_ROOT="$REPO_ROOT" CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" sh "$DETECT_SH" 2>&1)
if [ "$(kv "$out" POLICY_STATE)" = "pass" ] && [ "$(kv "$out" POLICY_FAILS)" = "0" ] && ! printf '%s\n' "$out" | grep -qE '^POLICY_(FINDING|SKIP)='; then
  pass "DET-D6-PASS: a current scaffold with both sub-checks run -> POLICY_STATE=pass, POLICY_FAILS=0, no finding or skip line"
else
  failc "DET-D6-PASS: $(printf '%s\n' "$out" | grep -E '^POLICY_' | tr '\n' ' ')"
fi
out=$(env TARGET_ROOT="$T" PLUGIN_CACHE_ROOT="$REPO_ROOT" sh "$DETECT_SH" 2>&1)
if [ "$(kv "$out" POLICY_STATE)" = "skip" ] && [ "$(kv "$out" DRIFT_STATE)" = "clean" ] \
   && printf '%s\n' "$out" | grep '^POLICY_SKIP=agent definitions not locally resolvable (tried: ' | grep -F "$T/.claude/agents" | grep -qF 'installed_plugins.json'; then
  pass "DET-D6-SKIP: no definitions resolvable -> POLICY_STATE=skip, DRIFT_STATE unaffected, and POLICY_SKIP carries the reason with the paths tried"
else
  failc "DET-D6-SKIP: $(printf '%s\n' "$out" | grep -E '^(DRIFT_STATE|POLICY_)' | tr '\n' ' ' | cut -c1-300)"
fi
# PR #186 review (Medium): a cache whose clone carries no sample makes D6 emit
# `PASS: D6` (the check projection) beside `SKIP: D6` (the required-row
# comparison deferred). That is a partial verification and must aggregate to
# skip, with the deferred sub-check's reason preserved.
NS="$WORK/cache-no-sample"; mkdir -p "$NS/setup/thin-root-layer" "$NS/scripts/spawn-policy" "$NS/scripts/lib" "$NS/.claude-plugin"
cp "$MANIFEST" "$NS/setup/manifest.json"; cp "$DRIFT_SRC" "$NS/setup/thin-root-layer/"
cp "$READOUT" "$NS/scripts/spawn-policy/"; cp "$REPO_ROOT/scripts/lib/plugin-root.sh" "$NS/scripts/lib/"
cp "$REPO_ROOT/.claude-plugin/marketplace.json" "$NS/.claude-plugin/"
raw=$(env CLAUDE_PROJECT_DIR="$T" CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" AUTOFLOW_MARKETPLACE_ROOT="$NS" sh "$NS/setup/thin-root-layer/drift-check.sh" 2>&1)
out=$(env TARGET_ROOT="$T" PLUGIN_CACHE_ROOT="$NS" CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" sh "$DETECT_SH" 2>&1)
if printf '%s\n' "$raw" | grep -q '^PASS: D6' && printf '%s\n' "$raw" | grep -q '^SKIP: D6' \
   && [ "$(kv "$out" POLICY_STATE)" = "skip" ] && [ "$(kv "$out" POLICY_FAILS)" = "0" ] \
   && [ "$(kv "$out" POLICY_SKIP)" = "required-row comparison deferred (marketplace clone at $NS carries no .claude/autoflow/spawn-policy.json sample)" ]; then
  pass "DET-D6-PARTIAL: the oracle emitting PASS: D6 beside SKIP: D6 (clone without a sample) aggregates to POLICY_STATE=skip, POLICY_SKIP naming the deferred comparison — never pass"
else
  failc "DET-D6-PARTIAL: oracle=$(printf '%s\n' "$raw" | grep -E '^(PASS|SKIP): D6' | cut -c1-40 | tr '\n' '|'); $(printf '%s\n' "$out" | grep -E '^POLICY_' | tr '\n' ' ' | cut -c1-300)"
fi
out=$(env TARGET_ROOT="$WORK/absent" PLUGIN_CACHE_ROOT="$REPO_ROOT" sh "$DETECT_SH" 2>&1)
if [ "$(kv "$out" INSTALL_STATE)" = "absent" ] && [ "$(kv "$out" POLICY_STATE)" = "na" ]; then
  pass "DET-D6-ABSENT: an absent target -> POLICY_STATE=na"
else
  failc "DET-D6-ABSENT: $(printf '%s\n' "$out" | grep -E '^(INSTALL_STATE|POLICY_STATE)' | tr '\n' ' ')"
fi
mk_oracle_cache() {  # <dir> <line...> — a scratch cache whose oracle emits the given lines and exits 1
  local d="$1"; shift
  mkdir -p "$d/setup/thin-root-layer"; cp "$MANIFEST" "$d/setup/manifest.json"
  { echo '#!/bin/sh'; for l in "$@"; do printf 'echo "%s"\n' "$l"; done; echo 'exit 1'; } > "$d/setup/thin-root-layer/drift-check.sh"
}
OC6="$WORK/oracle-d6"; mk_oracle_cache "$OC6" "FAIL: D6 -- missing phases row 'x' (agent_type y, effort z) — required by the current version; add it from the sample"
out=$(env TARGET_ROOT="$T" PLUGIN_CACHE_ROOT="$OC6" sh "$DETECT_SH" 2>&1)
if [ "$(kv "$out" DRIFT_STATE)" = "clean" ] && [ "$(kv "$out" DRIFT_FAILS)" = "0" ] && [ "$(kv "$out" POLICY_STATE)" = "fail" ] \
   && [ "$(kv "$out" POLICY_FAILS)" = "1" ] && [ "$(kv "$out" POLICY_FINDING)" = "missing phases row 'x' (agent_type y, effort z) — required by the current version; add it from the sample" ]; then
  pass "DET-D6-FILTERED: a D6-only failing oracle reads as DRIFT_STATE=clean with the finding carried verbatim on POLICY_FINDING"
else
  failc "DET-D6-FILTERED: $(printf '%s\n' "$out" | grep -E '^(DRIFT_|POLICY_)' | tr '\n' ' ' | cut -c1-300)"
fi
OC4="$WORK/oracle-d4-only"; mk_oracle_cache "$OC4" 'FAIL: D4 -- upstream drift: .claude/workflows/x.js differs from the marketplace clone'
out=$(env TARGET_ROOT="$T" PLUGIN_CACHE_ROOT="$OC4" sh "$DETECT_SH" 2>&1)
if [ "$(kv "$out" DRIFT_STATE)" = "drift" ] && [ "$(kv "$out" POLICY_STATE)" = "error" ]; then
  pass "DET-D6-ERROR: an oracle that emits no D6 verdict at all (pre-#185 oracle) -> POLICY_STATE=error, never pass; DRIFT unaffected"
else
  failc "DET-D6-ERROR: $(printf '%s\n' "$out" | grep -E '^(DRIFT_STATE|POLICY_STATE)' | tr '\n' ' ')"
fi
# PR #186 review (Low): FAIL and SKIP together — the projection failed while
# the row comparison did not run (a target with an effort mismatch against a
# cache whose clone has no sample). detect.sh must keep both field kinds, and
# SKILL.md Step 1 must report the skip lines regardless of the state.
set_policy "$T" '.phases.red.effort = "high"'
raw=$(env CLAUDE_PROJECT_DIR="$T" CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" AUTOFLOW_MARKETPLACE_ROOT="$NS" sh "$NS/setup/thin-root-layer/drift-check.sh" 2>&1)
out=$(env TARGET_ROOT="$T" PLUGIN_CACHE_ROOT="$NS" CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR" sh "$DETECT_SH" 2>&1)
if printf '%s\n' "$raw" | grep -q '^FAIL: D6' && printf '%s\n' "$raw" | grep -q '^SKIP: D6' \
   && [ "$(kv "$out" POLICY_STATE)" = "fail" ] && [ "$(kv "$out" POLICY_FAILS)" != "0" ] \
   && printf '%s\n' "$out" | grep '^POLICY_FINDING=' | grep -q "agent_type 'autoflow-tester' declare effort 'high'" \
   && [ "$(kv "$out" POLICY_SKIP)" = "required-row comparison deferred (marketplace clone at $NS carries no .claude/autoflow/spawn-policy.json sample)" ]; then
  pass "DET-D6-FAIL-SKIP: FAIL: D6 beside SKIP: D6 (effort mismatch + clone without a sample) -> POLICY_STATE=fail with the finding on POLICY_FINDING AND the deferred comparison on POLICY_SKIP — neither field kind is dropped"
else
  failc "DET-D6-FAIL-SKIP: oracle=$(printf '%s\n' "$raw" | grep -E '^(FAIL|SKIP): D6' | cut -c1-40 | tr '\n' '|'); $(printf '%s\n' "$out" | grep -E '^POLICY_' | tr '\n' ' ' | cut -c1-400)"
fi
set_policy "$T" '.'
# The synthetic oracle helper is defined above; a PASS beside two SKIPs.
OCPS="$WORK/oracle-pass-skip"; mk_oracle_cache "$OCPS" 'SKIP: D6 -- reason one (tried: /a; /b)' 'PASS: D6: scaffold agrees' 'SKIP: D6 -- reason two'
out=$(env TARGET_ROOT="$T" PLUGIN_CACHE_ROOT="$OCPS" sh "$DETECT_SH" 2>&1)
if [ "$(kv "$out" POLICY_STATE)" = "skip" ] && [ "$(printf '%s\n' "$out" | grep -c '^POLICY_SKIP=')" = "2" ] \
   && printf '%s\n' "$out" | grep -qx 'POLICY_SKIP=reason one (tried: /a; /b)' && printf '%s\n' "$out" | grep -qx 'POLICY_SKIP=reason two'; then
  pass "DET-D6-PASS-SKIP: a synthetic PASS+SKIP+SKIP oracle -> POLICY_STATE=skip with every SKIP reason carried verbatim, in order"
else
  failc "DET-D6-PASS-SKIP: $(printf '%s\n' "$out" | grep -E '^POLICY_' | tr '\n' ' ' | cut -c1-300)"
fi

# -----------------------------------------------------------------------------
echo "== SKILL / DOC: the operator-facing description =="
# -----------------------------------------------------------------------------
step1=$(awk '/^## Step 1/,/^## Step 2/' "$SKILL_MD")
step4=$(awk '/^## Step 4/,0' "$SKILL_MD")
if printf '%s\n' "$step1" | grep -q 'POLICY_STATE' && printf '%s\n' "$step1" | grep -q 'POLICY_FINDING' \
   && printf '%s\n' "$step1" | grep -q 'POLICY_SKIP' && printf '%s\n' "$step1" | grep -qi 'never overwrites'; then
  pass "SKILL-STEP1: Step 1 reads POLICY_STATE, lists every POLICY_FINDING and POLICY_SKIP line, and says the scaffold is never overwritten by the stamp"
else
  failc "SKILL-STEP1: Step 1 region lacks POLICY_STATE / POLICY_FINDING / the never-overwritten statement"
fi
# Review (Low): the skip lines are reported regardless of the aggregate state,
# and a skip naming the missing sample defers the sample-based remedy.
if printf '%s\n' "$step1" | tr '\n' ' ' | tr -s ' ' | grep -qi 'whatever `POLICY_STATE` is.*every.*`POLICY_SKIP=` line' \
   && printf '%s\n' "$step1" | tr '\n' ' ' | grep -q '/plugin marketplace update autoflow'; then
  pass "SKILL-STEP1-SKIP-ALWAYS: Step 1 lists every POLICY_SKIP line whatever POLICY_STATE is, and routes a missing-sample skip to a clone refresh before the sample-based remedy"
else
  failc "SKILL-STEP1-SKIP-ALWAYS: Step 1 does not report POLICY_SKIP independent of POLICY_STATE, or lacks the clone-refresh routing"
fi
if printf '%s\n' "$step4" | grep -q 'FAIL: D6' && printf '%s\n' "$step4" | grep -q 'spawn-policy.json'; then
  pass "SKILL-STEP4: Step 4 reports the D6 lines as rows to fix and names the sample to add missing rows from"
else
  failc "SKILL-STEP4: Step 4 region lacks the D6 report / sample path"
fi
if grep -q '^#   D6  ' "$DRIFT_SRC" && grep -q 'D6 → edit the target-owned' "$DRIFT_SRC"; then
  pass "DOC-HEADER: drift-check.sh lists D6 in its checks and its exit remedies"
else
  failc "DOC-HEADER: drift-check.sh header lacks the D6 entry / remedy"
fi
if grep -q '^| D6 |' "$REPO_ROOT/setup/SETUP-GUIDE.md" && grep -q 'six checks' "$REPO_ROOT/setup/SETUP-GUIDE.md"; then
  pass "DOC-SETUP-GUIDE: the drift table carries a D6 row and the count reads six"
else
  failc "DOC-SETUP-GUIDE: setup/SETUP-GUIDE.md lacks the D6 row / six-check count"
fi
if grep -q 'D6' "$REPO_ROOT/docs/tool-delivery-contract.md"; then
  pass "DOC-CONTRACT: docs/tool-delivery-contract.md R4 names D6"
else
  failc "DOC-CONTRACT: docs/tool-delivery-contract.md does not name D6"
fi
if awk '/^## PREFLIGHT/,/^## DIAGNOSE/' "$REPO_ROOT/docs/autoflow-guide.md" | grep -q 'D6'; then
  pass "DOC-PREFLIGHT: docs/autoflow-guide.md > PREFLIGHT names D6 and its remedy"
else
  failc "DOC-PREFLIGHT: docs/autoflow-guide.md > PREFLIGHT does not name D6"
fi
row_hash=$(jq -r '.artifacts[] | select(.dest == ".claude/autoflow/drift-check.sh") | .sha256' "$MANIFEST")
src_hash=$(shasum -a 256 "$DRIFT_SRC" 2>/dev/null | awk '{print $1}')
if [ -n "$row_hash" ] && [ "$row_hash" = "$src_hash" ]; then
  pass "MAN-ROW: setup/manifest.json carries the current drift-check.sh hash"
else
  failc "MAN-ROW: manifest row hash='$row_hash' source hash='$src_hash' (run setup/gen-manifest-hashes.sh)"
fi

echo
echo "=============================================="
echo "PASS: $PASS  FAIL: $FAIL"
echo "=============================================="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
