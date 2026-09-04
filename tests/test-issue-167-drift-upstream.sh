#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/lib/plugin-root.sh setup/thin-root-layer/drift-check.sh plugin/autoflow/skills/install/scripts/detect.sh setup/gen-manifest-hashes.sh setup/manifest.json setup/init.sh setup/SETUP-GUIDE.md docs/tool-delivery-contract.md docs/autoflow-guide.md
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: issue #167 — drift-check blind spot. A thin-root bundle that is
#       self-consistent (D1 PASS) but older than the marketplace clone ran for
#       three weeks (connev-llm/llmroute #595) because D2 only resolved the
#       plugin through the hook-only CLAUDE_PLUGIN_ROOT (always SKIP from a
#       plain shell) and nothing compared the installed bundle with upstream.
# =============================================================================
# Subjects:
#   scripts/lib/plugin-root.sh          — plugin root / marketplace clone
#                                         resolver (shared with #169's
#                                         spawn-policy.sh check fallback)
#   setup/thin-root-layer/drift-check.sh — D2 via the resolver; D4 (installed
#                                         manifest vs clone manifest, per
#                                         artifact sha256); D5 (installed
#                                         plugin files vs clone plugin source)
#   plugin/autoflow/skills/install/scripts/detect.sh — D4 counts as drift (a
#                                         re-stamp repairs it), D5 is filtered
#                                         like D2 (plugin-tier remedy)
#
# Every leg runs under a HERMETIC $CLAUDE_CONFIG_DIR (an empty scratch dir)
# and with CLAUDE_PLUGIN_ROOT / AUTOFLOW_MARKETPLACE_ROOT unset, so a developer
# machine's real ~/.claude/plugins never leaks into a verdict. Legs that need
# a registry or a clone build one under that scratch dir.
#
# Cases:
#   H-PLUGIN-ROOT-ENV     $CLAUDE_PLUGIN_ROOT wins when it holds plugin.json
#   H-PLUGIN-ROOT-PROJECT installed_plugins.json: the project-scope entry whose
#                         projectPath equals the target beats the user scope
#   H-PLUGIN-ROOT-USER    installed_plugins.json: user scope when no project
#                         entry matches
#   H-PLUGIN-ROOT-CACHE   no registry: the highest dotted version under
#                         plugins/cache/<mkt>/<plugin>/ (0.1.10 > 0.1.9)
#   H-PLUGIN-ROOT-NONE    nothing resolvable -> rc 1, empty stdout
#   H-MKT-ROOT-*          AUTOFLOW_MARKETPLACE_ROOT -> known_marketplaces.json
#                         -> plugins/marketplaces/<mkt> -> none (rc 1)
#   H-POSIX               the resolver sources under dash (when installed)
#   D2-CACHE-PASS         a stamped target + a synthetic cache at the manifest
#                         version -> PASS: D2 with no CLAUDE_PLUGIN_ROOT
#   D2-CACHE-FAIL         cache at another version -> FAIL: D2, exit 1
#   D2-SKIP               empty config dir -> SKIP: D2 naming the registry
#   D4-MATCH              clone == stamped source -> PASS: D4
#   D4-CHANGED-COPY       a copy row's upstream sha differs -> FAIL: D4 naming
#                         the dest, exit 1, HINT names init.sh --force
#   D4-CHANGED-SCAFFOLD   a scaffold row's upstream sha differs -> WARN, exit 0
#   D4-NEW-UPSTREAM       a row only upstream ships -> FAIL: D4, exit 1
#   D4-REMOVED-UPSTREAM   a row upstream dropped -> WARN, exit 0
#   D4-SKIP               no clone -> SKIP: D4
#   D4-CLONE-MALFORMED    a resolvable clone whose manifest is invalid JSON ->
#                         FAIL: D4 (never PASS), exit 1   [review finding 2]
#   D4-CLONE-SCHEMA       a clone manifest with no artifacts array -> FAIL: D4
#   ORACLE-PRE-RESOLVER   the source-tree oracle run against a target stamped
#                         BEFORE the resolver shipped (no scripts/lib/) still
#                         evaluates D4 (its own tree's copy) -> FAIL, not SKIP
#                                                            [review finding 1]
#   DET-PRE-RESOLVER      detect.sh on that same-version pre-resolver target
#                         with the current clone -> DRIFT_STATE=drift,
#                         VERSION_SKEW=no                    [review finding 1]
#   D5-MATCH              installed plugin == clone plugin source -> PASS: D5
#   D5-CHANGED            a clone hook file differs -> FAIL: D5 naming it,
#                         HINT names /plugin update
#   D5-EXTRA-IN-CACHE     loader bookkeeping in the cache only -> still PASS
#   DET-D5-FILTERED       detect.sh: a D5-only failing oracle -> DRIFT_STATE=clean
#   DET-D4-DRIFT          detect.sh: a D4 FAIL line -> DRIFT_STATE=drift
#   MAN-ROW               setup/manifest.json ships scripts/lib/plugin-root.sh
#                         as a copy row at the current source hash, and init.sh
#                         delivers it
#   DOC-*                 SETUP-GUIDE / tool-delivery-contract / autoflow-guide
#                         PREFLIGHT describe the upstream comparison and the
#                         stop condition
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

LIB="$REPO_ROOT/scripts/lib/plugin-root.sh"
DRIFT_SRC="$REPO_ROOT/setup/thin-root-layer/drift-check.sh"
DETECT_SH="$REPO_ROOT/plugin/autoflow/skills/install/scripts/detect.sh"
INIT_SH="$REPO_ROOT/setup/init.sh"
MANIFEST="$REPO_ROOT/setup/manifest.json"
PLUGIN_DIR="$REPO_ROOT/plugin/autoflow"
PLUGIN_VERSION="$(jq -r '.version' "$PLUGIN_DIR/.claude-plugin/plugin.json")"

PASS=0; FAIL=0
pass()  { echo "  PASS: $1"; PASS=$((PASS + 1)); }
failc() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT INT TERM

# Hermetic harness environment.
export CLAUDE_CONFIG_DIR="$WORK/empty-config"
mkdir -p "$CLAUDE_CONFIG_DIR"
unset CLAUDE_PLUGIN_ROOT AUTOFLOW_MARKETPLACE_ROOT

# resolve <fn> [args...] — run one resolver function in a fresh sh, under the
# ambient env; prints stdout, returns the function's rc.
resolve() { sh -c '. "$1"; shift; "$@"' _ "$LIB" "$@"; }

# mk_plugin <dir> <version> — a minimal plugin root (plugin.json + agents/).
mk_plugin() {
  mkdir -p "$1/.claude-plugin" "$1/agents"
  printf '{"name":"autoflow","version":"%s"}\n' "$2" > "$1/.claude-plugin/plugin.json"
}

# stamp <target> — a real init.sh stamp into <target>.
stamp() { mkdir -p "$1"; bash "$INIT_SH" --target "$1" >/dev/null 2>&1; }

# run_drift <target> [VAR=value ...] — the installed detector under the given
# extra env; sets DRIFT_OUT / DRIFT_RC.
run_drift() {
  local t="$1"; shift
  DRIFT_OUT=$(env CLAUDE_PROJECT_DIR="$t" "$@" sh "$t/.claude/autoflow/drift-check.sh" 2>&1)
  DRIFT_RC=$?
}

echo "=== Issue #167 — drift-check upstream comparison + plugin-root resolver ==="

# -----------------------------------------------------------------------------
echo "== H: scripts/lib/plugin-root.sh resolution order =="
# -----------------------------------------------------------------------------
if [ ! -f "$LIB" ]; then
  failc "H: $LIB is absent"
else
  ENVP="$WORK/env-plugin"; mk_plugin "$ENVP" "1.0.0"
  out=$(CLAUDE_PLUGIN_ROOT="$ENVP" resolve autoflow_plugin_root "$WORK/any"); rc=$?
  if [ "$rc" = 0 ] && [ "$out" = "$ENVP" ]; then
    pass "H-PLUGIN-ROOT-ENV: \$CLAUDE_PLUGIN_ROOT holding plugin.json is returned first"
  else
    failc "H-PLUGIN-ROOT-ENV: rc=$rc out='$out' (want $ENVP)"
  fi

  # A registry with a user-scope install and a project-scope install for TGT.
  CFG1="$WORK/cfg-registry"; mkdir -p "$CFG1/plugins"
  USERP="$CFG1/plugins/cache/autoflow/autoflow/0.1.9";  mk_plugin "$USERP" "0.1.9"
  PROJP="$CFG1/plugins/cache/autoflow/autoflow/0.1.7";  mk_plugin "$PROJP" "0.1.7"
  TGT="$WORK/target-with-project-scope"; mkdir -p "$TGT"
  jq -n --arg u "$USERP" --arg p "$PROJP" --arg t "$TGT" '{
    version: 2,
    plugins: { "autoflow@autoflow": [
      { scope: "user",    installPath: $u, version: "0.1.9" },
      { scope: "project", installPath: $p, version: "0.1.7", projectPath: $t }
    ] } }' > "$CFG1/plugins/installed_plugins.json"

  out=$(CLAUDE_CONFIG_DIR="$CFG1" resolve autoflow_plugin_root "$TGT"); rc=$?
  if [ "$rc" = 0 ] && [ "$out" = "$PROJP" ]; then
    pass "H-PLUGIN-ROOT-PROJECT: the project-scope entry for the target wins over the user scope"
  else
    failc "H-PLUGIN-ROOT-PROJECT: rc=$rc out='$out' (want $PROJP)"
  fi
  out=$(CLAUDE_CONFIG_DIR="$CFG1" resolve autoflow_plugin_root "$WORK/other-target"); rc=$?
  if [ "$rc" = 0 ] && [ "$out" = "$USERP" ]; then
    pass "H-PLUGIN-ROOT-USER: the user-scope entry is returned for a target with no project entry"
  else
    failc "H-PLUGIN-ROOT-USER: rc=$rc out='$out' (want $USERP)"
  fi

  # No registry at all: the cache scan picks the highest dotted version.
  CFG2="$WORK/cfg-cache-only"
  mk_plugin "$CFG2/plugins/cache/autoflow/autoflow/0.1.9"  "0.1.9"
  mk_plugin "$CFG2/plugins/cache/autoflow/autoflow/0.1.10" "0.1.10"
  mkdir -p "$CFG2/plugins/cache/autoflow/autoflow/not-a-version/.claude-plugin"
  out=$(CLAUDE_CONFIG_DIR="$CFG2" resolve autoflow_plugin_root "$WORK/any"); rc=$?
  if [ "$rc" = 0 ] && [ "$out" = "$CFG2/plugins/cache/autoflow/autoflow/0.1.10" ]; then
    pass "H-PLUGIN-ROOT-CACHE: without a registry the highest dotted version in the cache is returned (0.1.10 > 0.1.9; non-version dirs ignored)"
  else
    failc "H-PLUGIN-ROOT-CACHE: rc=$rc out='$out'"
  fi

  out=$(resolve autoflow_plugin_root "$WORK/any"); rc=$?
  if [ "$rc" = 1 ] && [ -z "$out" ]; then
    pass "H-PLUGIN-ROOT-NONE: nothing resolvable -> rc 1 with empty stdout"
  else
    failc "H-PLUGIN-ROOT-NONE: rc=$rc out='$out' (want rc 1, empty)"
  fi
  cands=$(resolve autoflow_plugin_root_candidates "$WORK/any")
  if printf '%s\n' "$cands" | grep -q 'installed_plugins.json' && printf '%s\n' "$cands" | grep -q 'plugins/cache/autoflow/autoflow'; then
    pass "H-PLUGIN-ROOT-CANDIDATES: the diagnostic names the registry and the cache path"
  else
    failc "H-PLUGIN-ROOT-CANDIDATES: diagnostic lacks the registry / cache paths: $cands"
  fi

  # Marketplace clone resolution.
  MK1="$WORK/mkt-env"; mkdir -p "$MK1"
  out=$(AUTOFLOW_MARKETPLACE_ROOT="$MK1" resolve autoflow_marketplace_root); rc=$?
  [ "$rc" = 0 ] && [ "$out" = "$MK1" ] \
    && pass "H-MKT-ROOT-ENV: \$AUTOFLOW_MARKETPLACE_ROOT is returned first" \
    || failc "H-MKT-ROOT-ENV: rc=$rc out='$out'"
  CFG3="$WORK/cfg-mkt"; mkdir -p "$CFG3/plugins" "$WORK/mkt-registered"
  jq -n --arg l "$WORK/mkt-registered" '{ autoflow: { installLocation: $l } }' > "$CFG3/plugins/known_marketplaces.json"
  out=$(CLAUDE_CONFIG_DIR="$CFG3" resolve autoflow_marketplace_root); rc=$?
  [ "$rc" = 0 ] && [ "$out" = "$WORK/mkt-registered" ] \
    && pass "H-MKT-ROOT-REGISTRY: known_marketplaces.json installLocation is returned" \
    || failc "H-MKT-ROOT-REGISTRY: rc=$rc out='$out'"
  CFG4="$WORK/cfg-mkt-conv"; mkdir -p "$CFG4/plugins/marketplaces/autoflow"
  out=$(CLAUDE_CONFIG_DIR="$CFG4" resolve autoflow_marketplace_root); rc=$?
  [ "$rc" = 0 ] && [ "$out" = "$CFG4/plugins/marketplaces/autoflow" ] \
    && pass "H-MKT-ROOT-CONVENTION: plugins/marketplaces/<mkt> is the last resort" \
    || failc "H-MKT-ROOT-CONVENTION: rc=$rc out='$out'"
  out=$(resolve autoflow_marketplace_root); rc=$?
  [ "$rc" = 1 ] && [ -z "$out" ] \
    && pass "H-MKT-ROOT-NONE: nothing resolvable -> rc 1 with empty stdout" \
    || failc "H-MKT-ROOT-NONE: rc=$rc out='$out'"

  if command -v dash >/dev/null 2>&1; then
    out=$(CLAUDE_CONFIG_DIR="$CFG2" dash -c '. "$1"; autoflow_plugin_root "$2"' _ "$LIB" "$WORK/any"); rc=$?
    [ "$rc" = 0 ] && [ "$out" = "$CFG2/plugins/cache/autoflow/autoflow/0.1.10" ] \
      && pass "H-POSIX: the resolver sources and resolves under dash" \
      || failc "H-POSIX: under dash rc=$rc out='$out'"
  else
    pass "H-POSIX: dash not installed here — leg not exercised (the /bin/sh legs above still ran)"
  fi
fi

# -----------------------------------------------------------------------------
echo "== D2: version skew resolved without CLAUDE_PLUGIN_ROOT =="
# -----------------------------------------------------------------------------
T1="$WORK/target-d2"; stamp "$T1"
if [ ! -f "$T1/.claude/autoflow/drift-check.sh" ] || [ ! -f "$T1/scripts/lib/plugin-root.sh" ]; then
  failc "D2: stamp into $T1 did not deliver drift-check.sh + scripts/lib/plugin-root.sh"
else
  CFG_OK="$WORK/cfg-d2-ok"; mk_plugin "$CFG_OK/plugins/cache/autoflow/autoflow/$PLUGIN_VERSION" "$PLUGIN_VERSION"
  run_drift "$T1" CLAUDE_CONFIG_DIR="$CFG_OK"
  if printf '%s\n' "$DRIFT_OUT" | grep -q "^PASS: D2: manifest version ($PLUGIN_VERSION) matches plugin pin"; then
    pass "D2-CACHE-PASS: the plugin is resolved from the cache and D2 PASSes with CLAUDE_PLUGIN_ROOT unset"
  else
    failc "D2-CACHE-PASS: no D2 PASS line — $(printf '%s\n' "$DRIFT_OUT" | grep '^.*: D2' | head -1)"
  fi

  CFG_SKEW="$WORK/cfg-d2-skew"; mk_plugin "$CFG_SKEW/plugins/cache/autoflow/autoflow/9.9.9" "9.9.9"
  run_drift "$T1" CLAUDE_CONFIG_DIR="$CFG_SKEW"
  if [ "$DRIFT_RC" -ne 0 ] && printf '%s\n' "$DRIFT_OUT" | grep -q '^FAIL: D2 -- version skew: manifest='"$PLUGIN_VERSION"' plugin=9.9.9'; then
    pass "D2-CACHE-FAIL: a cache at another version is a D2 FAIL (exit $DRIFT_RC) with no CLAUDE_PLUGIN_ROOT — the #595 blind spot is closed"
  else
    failc "D2-CACHE-FAIL: rc=$DRIFT_RC; $(printf '%s\n' "$DRIFT_OUT" | grep ': D2' | head -1)"
  fi

  run_drift "$T1"
  if [ "$DRIFT_RC" -eq 0 ] && printf '%s\n' "$DRIFT_OUT" | grep '^SKIP: D2' | grep -q 'installed_plugins.json'; then
    pass "D2-SKIP: with nothing resolvable D2 still SKIPs (exit 0) and names the registry it consulted"
  else
    failc "D2-SKIP: rc=$DRIFT_RC; $(printf '%s\n' "$DRIFT_OUT" | grep ': D2' | head -1)"
  fi
fi

# -----------------------------------------------------------------------------
echo "== D4: installed bundle vs marketplace clone (per-artifact sha256) =="
# -----------------------------------------------------------------------------
# A synthetic clone: the repo's own manifest + marketplace.json, so a leg can
# edit one row and observe exactly that row's disposition.
mk_clone() {  # <dir> <jq-filter over the manifest>
  mkdir -p "$1/setup" "$1/.claude-plugin"
  jq "$2" "$MANIFEST" > "$1/setup/manifest.json"
  cp "$REPO_ROOT/.claude-plugin/marketplace.json" "$1/.claude-plugin/marketplace.json"
}
if [ -f "$T1/.claude/autoflow/drift-check.sh" ]; then
  run_drift "$T1" AUTOFLOW_MARKETPLACE_ROOT="$REPO_ROOT"
  if [ "$DRIFT_RC" -eq 0 ] && printf '%s\n' "$DRIFT_OUT" | grep -q '^PASS: D4: installed bundle matches the marketplace clone'; then
    pass "D4-MATCH: a bundle stamped from the clone's own manifest PASSes D4"
  else
    failc "D4-MATCH: rc=$DRIFT_RC; $(printf '%s\n' "$DRIFT_OUT" | grep ': D4' | head -1)"
  fi

  COPY_DEST=".claude/workflows/architect-deliberation.js"
  C1="$WORK/clone-changed-copy"
  mk_clone "$C1" '(.artifacts[] | select(.dest == "'"$COPY_DEST"'") | .sha256) |= "0000000000000000000000000000000000000000000000000000000000000000"'
  run_drift "$T1" AUTOFLOW_MARKETPLACE_ROOT="$C1"
  if [ "$DRIFT_RC" -ne 0 ] && printf '%s\n' "$DRIFT_OUT" | grep -q "^FAIL: D4 -- upstream drift: $COPY_DEST differs from the marketplace clone"; then
    pass "D4-CHANGED-COPY: a copy row whose upstream hash differs is a D4 FAIL naming the dest (exit $DRIFT_RC) — detected with the version unchanged"
  else
    failc "D4-CHANGED-COPY: rc=$DRIFT_RC; $(printf '%s\n' "$DRIFT_OUT" | grep ': D4' | head -1)"
  fi
  if printf '%s\n' "$DRIFT_OUT" | grep '^HINT: D4' | grep -q 'setup/init.sh --target .* --force'; then
    pass "D4-CHANGED-COPY: the HINT names the re-stamp command"
  else
    failc "D4-CHANGED-COPY: no HINT naming init.sh --force"
  fi

  C2="$WORK/clone-changed-scaffold"
  mk_clone "$C2" '(.artifacts[] | select(.dest == ".claude/autoflow/spawn-policy.json") | .sha256) |= "1111111111111111111111111111111111111111111111111111111111111111"'
  run_drift "$T1" AUTOFLOW_MARKETPLACE_ROOT="$C2"
  if [ "$DRIFT_RC" -eq 0 ] && printf '%s\n' "$DRIFT_OUT" | grep -q '^WARN: D4 -- scaffold sample changed upstream: .claude/autoflow/spawn-policy.json' \
     && ! printf '%s\n' "$DRIFT_OUT" | grep -q '^FAIL: D4'; then
    pass "D4-CHANGED-SCAFFOLD: a changed scaffold sample is a WARN, not a FAIL (a re-stamp never overwrites it)"
  else
    failc "D4-CHANGED-SCAFFOLD: rc=$DRIFT_RC; $(printf '%s\n' "$DRIFT_OUT" | grep ': D4' | head -2 | tr '\n' ' ')"
  fi

  C3="$WORK/clone-new-row"
  mk_clone "$C3" '.artifacts += [{source:"scripts/new/tool.sh", dest:"scripts/new/tool.sh", tier:"root-layer", kind:"copy", sha256:"2222222222222222222222222222222222222222222222222222222222222222"}]'
  run_drift "$T1" AUTOFLOW_MARKETPLACE_ROOT="$C3"
  if [ "$DRIFT_RC" -ne 0 ] && printf '%s\n' "$DRIFT_OUT" | grep -q '^FAIL: D4 -- upstream drift: scripts/new/tool.sh is shipped by the marketplace clone but absent'; then
    pass "D4-NEW-UPSTREAM: an artifact only the clone ships is a D4 FAIL (a re-stamp delivers it)"
  else
    failc "D4-NEW-UPSTREAM: rc=$DRIFT_RC; $(printf '%s\n' "$DRIFT_OUT" | grep ': D4' | head -1)"
  fi

  C4="$WORK/clone-removed-row"
  mk_clone "$C4" 'del(.artifacts[] | select(.dest == "'"$COPY_DEST"'"))'
  run_drift "$T1" AUTOFLOW_MARKETPLACE_ROOT="$C4"
  if [ "$DRIFT_RC" -eq 0 ] && printf '%s\n' "$DRIFT_OUT" | grep -q "^WARN: D4 -- installed artifact no longer shipped upstream: $COPY_DEST"; then
    pass "D4-REMOVED-UPSTREAM: an installed artifact upstream dropped is a WARN, exit 0"
  else
    failc "D4-REMOVED-UPSTREAM: rc=$DRIFT_RC; $(printf '%s\n' "$DRIFT_OUT" | grep ': D4' | head -1)"
  fi

  run_drift "$T1"
  if [ "$DRIFT_RC" -eq 0 ] && printf '%s\n' "$DRIFT_OUT" | grep '^SKIP: D4' | grep -q 'known_marketplaces.json'; then
    pass "D4-SKIP: no clone resolvable -> SKIP naming the registry, exit 0"
  else
    failc "D4-SKIP: rc=$DRIFT_RC; $(printf '%s\n' "$DRIFT_OUT" | grep ': D4' | head -1)"
  fi

  # Review finding 2 (PR #172): a resolvable clone whose manifest cannot be
  # read must not read as "matches".
  C6="$WORK/clone-malformed"; mkdir -p "$C6/setup"
  printf '{ not json\n' > "$C6/setup/manifest.json"
  run_drift "$T1" AUTOFLOW_MARKETPLACE_ROOT="$C6"
  if [ "$DRIFT_RC" -ne 0 ] && printf '%s\n' "$DRIFT_OUT" | grep -q '^FAIL: D4 -- marketplace clone manifest at .* is not usable' \
     && ! printf '%s\n' "$DRIFT_OUT" | grep -q '^PASS: D4'; then
    pass "D4-CLONE-MALFORMED: an invalid-JSON clone manifest is a D4 FAIL (exit $DRIFT_RC), never a PASS"
  else
    failc "D4-CLONE-MALFORMED: rc=$DRIFT_RC; $(printf '%s\n' "$DRIFT_OUT" | grep ': D4' | head -1)"
  fi
  C7="$WORK/clone-schema"; mkdir -p "$C7/setup"
  printf '{"version":"%s","artifacts":{}}\n' "$PLUGIN_VERSION" > "$C7/setup/manifest.json"
  run_drift "$T1" AUTOFLOW_MARKETPLACE_ROOT="$C7"
  if [ "$DRIFT_RC" -ne 0 ] && printf '%s\n' "$DRIFT_OUT" | grep -q '^FAIL: D4 -- marketplace clone manifest at .* is not usable'; then
    pass "D4-CLONE-SCHEMA: a clone manifest with no artifacts array is a D4 FAIL"
  else
    failc "D4-CLONE-SCHEMA: rc=$DRIFT_RC; $(printf '%s\n' "$DRIFT_OUT" | grep ': D4' | head -1)"
  fi
fi

# -----------------------------------------------------------------------------
echo "== PRE-RESOLVER: a target stamped before scripts/lib/ shipped (review finding 1) =="
# -----------------------------------------------------------------------------
# Simulate the bundle every current target carries: stamped at the same
# version, self-consistent (D1 PASS), no resolver and no manifest row for it,
# and one artifact older than the clone's. The cache oracle — the source
# tree's drift-check.sh, as detect.sh runs it — must still evaluate D4 from
# its own tree's resolver copy, and detect.sh must report drift on it with
# the version unchanged.
TP="$WORK/target-pre-resolver"; stamp "$TP"
if [ ! -f "$TP/.claude/autoflow/manifest.json" ]; then
  failc "PRE-RESOLVER: stamp into $TP failed"
else
  rm -f "$TP/scripts/lib/plugin-root.sh"
  jq 'del(.artifacts[] | select(.dest == "scripts/lib/plugin-root.sh"))' "$TP/.claude/autoflow/manifest.json" > "$TP/.m" && mv "$TP/.m" "$TP/.claude/autoflow/manifest.json"
  OLD_WF="$TP/.claude/workflows/verify-cause-branch.js"
  printf '\n// pre-fix revision\n' >> "$OLD_WF"
  old_h=$(shasum -a 256 "$OLD_WF" | awk '{print $1}')
  jq --arg h "$old_h" '(.artifacts[] | select(.dest == ".claude/workflows/verify-cause-branch.js") | .sha256) |= $h' "$TP/.claude/autoflow/manifest.json" > "$TP/.m" && mv "$TP/.m" "$TP/.claude/autoflow/manifest.json"

  out=$(env CLAUDE_PROJECT_DIR="$TP" AUTOFLOW_MARKETPLACE_ROOT="$REPO_ROOT" sh "$DRIFT_SRC" 2>&1); rc=$?
  if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q '^FAIL: D4 -- upstream drift: .claude/workflows/verify-cause-branch.js differs' \
     && ! printf '%s\n' "$out" | grep -q '^SKIP: D4' && ! printf '%s\n' "$out" | grep -q '^FAIL: D1'; then
    pass "ORACLE-PRE-RESOLVER: the source-tree oracle sources its own resolver copy and reports the older artifact as D4 drift (D1 clean, no SKIP)"
  else
    failc "ORACLE-PRE-RESOLVER: rc=$rc; $(printf '%s\n' "$out" | grep -E ': D[14]' | head -3 | tr '\n' ' ')"
  fi

  out=$(TARGET_ROOT="$TP" PLUGIN_CACHE_ROOT="$REPO_ROOT" sh "$DETECT_SH" 2>&1)
  if printf '%s\n' "$out" | grep -q '^DRIFT_STATE=drift$' && printf '%s\n' "$out" | grep -q '^VERSION_SKEW=no$' \
     && printf '%s\n' "$out" | grep -q '^DRIFT_FIRST=upstream drift: '; then
    pass "DET-PRE-RESOLVER: detect.sh reports DRIFT_STATE=drift with VERSION_SKEW=no on a same-version target stamped before the resolver shipped (DRIFT_FIRST: $(printf '%s\n' "$out" | sed -n 's/^DRIFT_FIRST=//p' | cut -c1-80))"
  else
    failc "DET-PRE-RESOLVER: $(printf '%s\n' "$out" | grep -E '^(DRIFT|VERSION)' | tr '\n' ' ')"
  fi
fi

# -----------------------------------------------------------------------------
echo "== D5: installed plugin vs marketplace clone plugin source =="
# -----------------------------------------------------------------------------
if [ -f "$T1/.claude/autoflow/drift-check.sh" ]; then
  run_drift "$T1" AUTOFLOW_MARKETPLACE_ROOT="$REPO_ROOT" CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR"
  if [ "$DRIFT_RC" -eq 0 ] && printf '%s\n' "$DRIFT_OUT" | grep -q "^PASS: D5: installed plugin ($PLUGIN_VERSION at $PLUGIN_DIR) matches the marketplace clone's plugin source"; then
    pass "D5-MATCH: an installed plugin equal to the clone's plugin source PASSes D5"
  else
    failc "D5-MATCH: rc=$DRIFT_RC; $(printf '%s\n' "$DRIFT_OUT" | grep ': D5' | head -1)"
  fi

  # A clone whose plugin source carries a hook edit the installed plugin lacks.
  C5="$WORK/clone-hook-changed"; mkdir -p "$C5/setup" "$C5/.claude-plugin"
  cp "$MANIFEST" "$C5/setup/manifest.json"
  cp "$REPO_ROOT/.claude-plugin/marketplace.json" "$C5/.claude-plugin/"
  mkdir -p "$C5/plugin"; cp -R "$PLUGIN_DIR" "$C5/plugin/autoflow"
  printf '\n# upstream hook edit\n' >> "$C5/plugin/autoflow/hooks/check-autoflow-gate.sh"
  run_drift "$T1" AUTOFLOW_MARKETPLACE_ROOT="$C5" CLAUDE_PLUGIN_ROOT="$PLUGIN_DIR"
  if [ "$DRIFT_RC" -ne 0 ] && printf '%s\n' "$DRIFT_OUT" | grep -q '^FAIL: D5 -- plugin skew: hooks/check-autoflow-gate.sh differs between the installed plugin' \
     && printf '%s\n' "$DRIFT_OUT" | grep '^HINT: D5' | grep -q '/plugin update autoflow@autoflow'; then
    pass "D5-CHANGED: a hook that differs between the installed plugin and the clone is a D5 FAIL naming it, with the /plugin update remedy"
  else
    failc "D5-CHANGED: rc=$DRIFT_RC; $(printf '%s\n' "$DRIFT_OUT" | grep -E ': D5|HINT: D5' | head -2 | tr '\n' ' ')"
  fi

  # Loader bookkeeping present only in the installed copy is not skew.
  P6="$WORK/plugin-with-bookkeeping"; mkdir -p "$P6"; cp -R "$PLUGIN_DIR"/. "$P6/"; : > "$P6/.in_use"
  run_drift "$T1" AUTOFLOW_MARKETPLACE_ROOT="$REPO_ROOT" CLAUDE_PLUGIN_ROOT="$P6"
  if [ "$DRIFT_RC" -eq 0 ] && printf '%s\n' "$DRIFT_OUT" | grep -q '^PASS: D5'; then
    pass "D5-EXTRA-IN-CACHE: a file only the installed copy carries (.in_use) does not fail D5"
  else
    failc "D5-EXTRA-IN-CACHE: rc=$DRIFT_RC; $(printf '%s\n' "$DRIFT_OUT" | grep ': D5' | head -1)"
  fi
fi

# -----------------------------------------------------------------------------
echo "== DET: install-skill detect.sh disposition of the new lines =="
# -----------------------------------------------------------------------------
if [ ! -f "$DETECT_SH" ]; then
  failc "DET: $DETECT_SH absent"
else
  # A scratch cache whose oracle drift-check emits exactly one line class.
  mk_oracle_cache() {  # <dir> <line>
    mkdir -p "$1/setup/thin-root-layer"
    cp "$MANIFEST" "$1/setup/manifest.json"
    printf '%s\n' '#!/bin/sh' "echo \"$2\"" 'exit 1' > "$1/setup/thin-root-layer/drift-check.sh"
  }
  DT="$WORK/target-detect"; stamp "$DT"
  OC5="$WORK/oracle-d5"; mk_oracle_cache "$OC5" 'FAIL: D5 -- plugin skew: hooks/x.sh differs'
  out=$(TARGET_ROOT="$DT" PLUGIN_CACHE_ROOT="$OC5" sh "$DETECT_SH" 2>&1)
  if printf '%s\n' "$out" | grep -q '^DRIFT_STATE=clean$' && printf '%s\n' "$out" | grep -q '^DRIFT_FAILS=0$'; then
    pass "DET-D5-FILTERED: a D5-only failing oracle reads as DRIFT_STATE=clean (plugin-tier remedy, not a stamp)"
  else
    failc "DET-D5-FILTERED: $(printf '%s\n' "$out" | grep '^DRIFT_' | tr '\n' ' ')"
  fi
  OC4="$WORK/oracle-d4"; mk_oracle_cache "$OC4" 'FAIL: D4 -- upstream drift: .claude/workflows/x.js differs from the marketplace clone'
  out=$(TARGET_ROOT="$DT" PLUGIN_CACHE_ROOT="$OC4" sh "$DETECT_SH" 2>&1)
  if printf '%s\n' "$out" | grep -q '^DRIFT_STATE=drift$' && printf '%s\n' "$out" | grep -q '^DRIFT_FIRST=upstream drift: .claude/workflows/x.js'; then
    pass "DET-D4-DRIFT: a D4 FAIL line reads as DRIFT_STATE=drift with DRIFT_FIRST carrying it (a re-stamp is the remedy the skill offers)"
  else
    failc "DET-D4-DRIFT: $(printf '%s\n' "$out" | grep '^DRIFT_' | tr '\n' ' ')"
  fi
fi

# -----------------------------------------------------------------------------
echo "== MAN: the resolver ships with the bundle =="
# -----------------------------------------------------------------------------
row_hash=$(jq -r '.artifacts[] | select(.dest == "scripts/lib/plugin-root.sh" and .kind == "copy") | .sha256' "$MANIFEST")
src_hash=$(shasum -a 256 "$LIB" 2>/dev/null | awk '{print $1}')
if [ -n "$row_hash" ] && [ "$row_hash" = "$src_hash" ]; then
  pass "MAN-ROW: setup/manifest.json carries scripts/lib/plugin-root.sh as a copy row at the current source hash"
else
  failc "MAN-ROW: manifest row hash='$row_hash' source hash='$src_hash' (run setup/gen-manifest-hashes.sh)"
fi
if [ -f "$T1/scripts/lib/plugin-root.sh" ] && cmp -s "$T1/scripts/lib/plugin-root.sh" "$LIB"; then
  pass "MAN-ROW: init.sh delivers scripts/lib/plugin-root.sh byte-identical into the target"
else
  failc "MAN-ROW: init.sh did not deliver scripts/lib/plugin-root.sh"
fi

# -----------------------------------------------------------------------------
echo "== DOC: the operator-facing description =="
# -----------------------------------------------------------------------------
SG="$REPO_ROOT/setup/SETUP-GUIDE.md"
if grep -q 'marketplace clone' "$SG" && grep -qE 'D4' "$SG" && grep -q 'CLAUDE_PLUGIN_ROOT' "$SG"; then
  pass "DOC-SETUP-GUIDE: describes the upstream (D4) comparison and how the plugin is resolved without CLAUDE_PLUGIN_ROOT"
else
  failc "DOC-SETUP-GUIDE: setup/SETUP-GUIDE.md lacks the D4 / marketplace-clone / CLAUDE_PLUGIN_ROOT description"
fi
TDC="$REPO_ROOT/docs/tool-delivery-contract.md"
if tr '\n' ' ' < "$TDC" | tr -s ' ' | grep -q 'marketplace clone'; then
  pass "DOC-CONTRACT: docs/tool-delivery-contract.md R4 names the marketplace-clone comparison"
else
  failc "DOC-CONTRACT: docs/tool-delivery-contract.md does not name the marketplace-clone comparison"
fi
AG="$REPO_ROOT/docs/autoflow-guide.md"
if awk '/^## PREFLIGHT/,/^## DIAGNOSE/' "$AG" | grep -q 'drift-check.sh'; then
  pass "DOC-PREFLIGHT: docs/autoflow-guide.md > PREFLIGHT runs drift-check.sh as a stop condition"
else
  failc "DOC-PREFLIGHT: docs/autoflow-guide.md > PREFLIGHT does not name drift-check.sh"
fi

echo
echo "=============================================="
echo "PASS: $PASS  FAIL: $FAIL"
echo "=============================================="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
