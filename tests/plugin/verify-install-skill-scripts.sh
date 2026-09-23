#!/bin/sh
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: /autoflow:install skill — installed-layout wiring + manifest version
# =============================================================================
# Plain POSIX sh + jq/awk/grep only.
#
#   AC3b'-lockstep (manifest)  setup/manifest.json .version == the plugin's
#          plugin.json .version: init.sh copies setup/manifest.json into every
#          target as .claude/autoflow/manifest.json, and drift-check D2
#          compares that version against the installed plugin's plugin.json,
#          so a desync fails every clean install's drift-check
#   AC-174-5 (packaging)  the plugin package copied to the /plugin install
#          layout <config>/plugins/cache/<mkt>/<plugin>/<version>/, and the
#          SKILL.md Step 0 bash block evaluated there with CLAUDE_PLUGIN_ROOT
#          set: S == the installed plugin's skills/install/scripts,
#          PLUGIN_CACHE_ROOT == the marketplace clone known_marketplaces.json
#          registers, TARGET_ROOT == CLAUDE_PROJECT_DIR
# =============================================================================

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)

CACHE_MANIFEST="$REPO_ROOT/setup/manifest.json"
CACHE_PLUGIN_JSON="$REPO_ROOT/plugin/autoflow/.claude-plugin/plugin.json"
PLUGIN_SRC="$REPO_ROOT/plugin/autoflow"
SKILL_MD="$REPO_ROOT/plugin/autoflow/skills/install/SKILL.md"

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
pass()  { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
failc() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s -- %s\n' "$1" "$2"; }
skipc() { SKIP_COUNT=$((SKIP_COUNT + 1)); printf 'SKIP: %s -- %s\n' "$1" "$2"; }

# ── Helpers ───────────────────────────────────────────────────────────────────

# get_kv <output> <key> — last matching key=value line's value.
get_kv() {
  printf '%s\n' "$1" | grep "^$2=" | tail -1 | cut -d= -f2-
}

# same_dir <a> <b> — physical-path equality (mktemp on macOS returns /var/...,
# a symlink to /private/var/...; a `cd && pwd` on one side may differ textually).
same_dir() {
  [ -d "$1" ] && [ -d "$2" ] && [ "$(CDPATH= cd -- "$1" && pwd -P)" = "$(CDPATH= cd -- "$2" && pwd -P)" ]
}
# mk_clone <dir> — a minimal marketplace clone: the setup/manifest.json the
# resolver requires of a candidate.
mk_clone() {
  mkdir -p "$1/setup"
  cp "$CACHE_MANIFEST" "$1/setup/manifest.json"
}
# mk_cache_plugin <config-dir> <version> — the versioned plugin copy the
# harness installs; prints its path (that install's CLAUDE_PLUGIN_ROOT).
mk_cache_plugin() {
  _cp="$1/plugins/cache/autoflow/autoflow/$2"
  mkdir -p "$_cp"
  cp -R "$PLUGIN_SRC"/. "$_cp/"
  printf '%s\n' "$_cp"
}

# ── Temp fixtures ─────────────────────────────────────────────────────────────
WORK_DIR=$(mktemp -d)                 # scratch CLAUDE_CONFIG_DIR carrying the
                                       # plugin-cache layout + clone fixture
STEP0_TARGET=$(mktemp -d)             # the consuming project Step 0 runs in

cleanup() {
  rm -rf "$WORK_DIR" "$STEP0_TARGET"
}
# An inherited AUTOFLOW_MARKETPLACE_ROOT is the resolver's first candidate and
# would shadow the registered clone; the leg passes CLAUDE_PLUGIN_ROOT itself.
unset CLAUDE_PLUGIN_ROOT AUTOFLOW_MARKETPLACE_ROOT
trap 'cleanup' EXIT INT TERM

# ══════════════════════════════════════════════════════════════════════════════
# AC3b'-lockstep — the stamped manifest version matches the plugin version
# ══════════════════════════════════════════════════════════════════════════════

echo "== AC3b'-lockstep: cache setup/manifest.json .version == cache plugin.json .version =="
if [ -f "$CACHE_MANIFEST" ] && [ -f "$CACHE_PLUGIN_JSON" ]; then
  MVER=$(jq -r '.version // empty' "$CACHE_MANIFEST")
  PVER=$(jq -r '.version // empty' "$CACHE_PLUGIN_JSON")
  if [ -n "$MVER" ] && [ "$MVER" = "$PVER" ]; then
    pass "AC3b'-lockstep: cache setup/manifest.json.version ($MVER) == plugin.json.version ($PVER) -- R2-stamp lockstep holds"
  else
    failc "AC3b'-lockstep" "cache version lockstep broken: setup/manifest.json.version='$MVER' plugin.json.version='$PVER' -- every clean install's drift-check D2 would report version skew"
  fi
else
  failc "AC3b'-lockstep" "cache setup/manifest.json or plugin.json missing"
fi

# ══════════════════════════════════════════════════════════════════════════════
# AC-174-5 — Step 0 clone resolution under the plugin-cache layout
# ══════════════════════════════════════════════════════════════════════════════
# Under `/plugin install autoflow@autoflow` the harness copies the plugin to
# <config>/plugins/cache/<mkt>/<plugin>/<version>/ (installed_plugins.json
# `installPath`; Claude Code 2.1.260): a tree whose grandparent is
# cache/<mkt>/ and holds no setup/. The leg builds that layout under a scratch
# CLAUDE_CONFIG_DIR and evaluates the Step 0 derivation from it.
CFG="$WORK_DIR/cfg-registry"; mkdir -p "$CFG/plugins"
CACHE_PLUGIN=$(mk_cache_plugin "$CFG" 0.1.9)
CLONE="$WORK_DIR/clone-registered"; mk_clone "$CLONE"
jq -n --arg loc "$CLONE" '{autoflow:{source:{source:"github",repo:"Munsik-Park/autoflow"},installLocation:$loc,lastUpdated:"2026-09-04T00:00:00.000Z"}}' \
  > "$CFG/plugins/known_marketplaces.json"

echo "== AC-174-5: the SKILL.md Step 0 bash block, evaluated under the cache layout, yields PLUGIN_CACHE_ROOT == the clone (the derivation itself) =="
STEP0_BLOCK=$(awk '/^## Step 0/{f=1; next} /^## Step 1/{f=0} f' "$SKILL_MD" \
  | awk '/^```bash/{b=1; next} /^```/{if (b) exit} b')
if [ -z "$STEP0_BLOCK" ]; then
  failc "AC-174-5" "could not extract a bash fence from the SKILL.md Step 0 region"
else
  _s0f="$WORK_DIR/step0.sh"
  { printf '%s\n' "$STEP0_BLOCK"; printf 'printf "S=%%s\\nPLUGIN_CACHE_ROOT=%%s\\nTARGET_ROOT=%%s\\n" "$S" "$PLUGIN_CACHE_ROOT" "$TARGET_ROOT"\n'; } > "$_s0f"
  _s0out=$(cd "$STEP0_TARGET" && CLAUDE_CONFIG_DIR="$CFG" CLAUDE_PLUGIN_ROOT="$CACHE_PLUGIN" CLAUDE_PROJECT_DIR="$STEP0_TARGET" bash "$_s0f" 2>"$WORK_DIR/step0.err")
  _s0S=$(get_kv "$_s0out" S); _s0root=$(get_kv "$_s0out" PLUGIN_CACHE_ROOT); _s0t=$(get_kv "$_s0out" TARGET_ROOT)
  if [ "$_s0S" = "$CACHE_PLUGIN/skills/install/scripts" ] && same_dir "$_s0root" "$CLONE" && [ "$_s0t" = "$STEP0_TARGET" ]; then
    pass "AC-174-5: Step 0 evaluated -> S=<cache plugin>/skills/install/scripts, PLUGIN_CACHE_ROOT=<registered clone>, TARGET_ROOT=<project>"
  else
    failc "AC-174-5" "Step 0 block evaluated to S='$_s0S' PLUGIN_CACHE_ROOT='$_s0root' TARGET_ROOT='$_s0t' (expected S=$CACHE_PLUGIN/skills/install/scripts, root=$CLONE, target=$STEP0_TARGET); stderr='$(head -c 300 "$WORK_DIR/step0.err")'"
  fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# Summary
# ══════════════════════════════════════════════════════════════════════════════
echo "=============================================="
echo "RESULT: $PASS_COUNT passed, $FAIL_COUNT failed, $SKIP_COUNT skipped (of $((PASS_COUNT + FAIL_COUNT)) checks)"
if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
