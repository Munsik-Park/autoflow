#!/bin/sh
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# AutoFlow thin-root drift detector (issue #792 [#785-S5], WI-3)
# =============================================================================
# Target-local, network-free self-verify. Shipped into a consuming target at
# .claude/autoflow/drift-check.sh by `setup/init.sh --target`. Reads the
# installed manifest (.claude/autoflow/manifest.json) and asserts the landed
# artifacts still match it. Runs with no dependency on the AutoFlow source repo.
#
# Resolution:
#   TARGET_ROOT = ${CLAUDE_PROJECT_DIR:-<this script's ../..>}
#
# Checks (map 1:1 to docs/tool-delivery-contract.md R4):
#   D1  manifest coverage + content drift (dispatch by artifact kind)
#   D2  version skew: installed manifest version vs plugin pin
#       (SKIP when the plugin root is not locally resolvable — not a failure)
#   D3  hook/state-root invariant: state resolves from CLAUDE_PROJECT_DIR
#
# Exit: 0 = no drift (D2 SKIP allowed); 1 = any D1/D3 FAIL.
#   A FAIL is a PREFLIGHT stop condition (see setup/SETUP-GUIDE.md).
# =============================================================================

set -u

# ── Resolve the target root ───────────────────────────────────────────────────
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  TARGET_ROOT="$CLAUDE_PROJECT_DIR"
else
  TARGET_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
fi

MANIFEST="$TARGET_ROOT/.claude/autoflow/manifest.json"
SHIM_REF="$TARGET_ROOT/.claude/autoflow/claude-md-shim.md"
PIN_REF="$TARGET_ROOT/.claude/autoflow/settings-pin.json"

FAIL_COUNT=0
SKIP_COUNT=0
pass()  { printf 'PASS: %s\n' "$1"; }
failc() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s -- %s\n' "$1" "$2"; }
skipc() { SKIP_COUNT=$((SKIP_COUNT + 1)); printf 'SKIP: %s -- %s\n' "$1" "$2"; }

if ! command -v jq >/dev/null 2>&1; then
  printf 'FAIL: drift-check -- jq is required but not found\n'
  exit 1
fi
if [ ! -f "$MANIFEST" ]; then
  printf 'FAIL: drift-check -- installed manifest missing: %s\n' "$MANIFEST"
  exit 1
fi

# Portable sha256 of a file.
sha256_of() {
  _h=$(shasum -a 256 "$1" 2>/dev/null | awk '{print $1}')
  [ -n "$_h" ] || _h=$(sha256sum "$1" 2>/dev/null | awk '{print $1}')
  printf '%s' "$_h"
}

# ── D1: manifest coverage + content drift ─────────────────────────────────────
echo "== D1: manifest coverage + content drift =="
_n=$(jq -r '.artifacts | length' "$MANIFEST")
_i=0
while [ "$_i" -lt "$_n" ]; do
  _dest=$(jq -r ".artifacts[$_i].dest" "$MANIFEST")
  _kind=$(jq -r ".artifacts[$_i].kind" "$MANIFEST")
  _hash=$(jq -r ".artifacts[$_i].sha256 // \"null\"" "$MANIFEST")
  _abs="$TARGET_ROOT/$_dest"
  case "$_kind" in
    copy)
      if [ ! -f "$_abs" ]; then
        failc "D1" "missing installed artifact: $_dest"
      elif [ "$_hash" = "null" ] || [ -z "$_hash" ]; then
        pass "D1 copy: $_dest present (no hash pinned)"
      else
        _actual=$(sha256_of "$_abs")
        if [ "$_actual" = "$_hash" ]; then
          pass "D1 copy: $_dest content matches manifest"
        else
          failc "D1" "content drift: $_dest (manifest=$_hash actual=$_actual)"
        fi
      fi
      ;;
    shim-stamp)
      _claude="$TARGET_ROOT/$_dest"
      if [ ! -f "$_claude" ]; then
        failc "D1" "missing shim host file: $_dest"
      elif [ ! -f "$SHIM_REF" ]; then
        failc "D1" "canonical shim reference missing: .claude/autoflow/claude-md-shim.md"
      else
        _region=$(awk '/AUTOFLOW-IMPORT:BEGIN/,/AUTOFLOW-IMPORT:END/' "$_claude")
        if [ "$_region" = "$(cat "$SHIM_REF")" ]; then
          pass "D1 shim-stamp: $_dest managed region matches canonical shim"
        else
          failc "D1" "shim region drift in $_dest (managed block edited)"
        fi
      fi
      ;;
    json-merge)
      _settings="$TARGET_ROOT/$_dest"
      if [ ! -f "$_settings" ]; then
        failc "D1" "missing merged settings: $_dest"
      elif [ ! -f "$PIN_REF" ]; then
        failc "D1" "pin reference missing: .claude/autoflow/settings-pin.json"
      elif ! jq -e . "$_settings" >/dev/null 2>&1; then
        failc "D1" "invalid JSON: $_dest"
      else
        # Subset: merging the pin into settings must add nothing (pin already present).
        _sub=$(jq -s '(.[0] * .[1]) == .[0]' "$_settings" "$PIN_REF" 2>/dev/null)
        if [ "$_sub" = "true" ]; then
          pass "D1 json-merge: $_dest still carries the pin keys"
        else
          failc "D1" "pin drift in $_dest (a pinned key was removed or changed)"
        fi
      fi
      ;;
    scaffold)
      if [ -e "$_abs" ]; then
        pass "D1 scaffold: $_dest present (content target-owned, not checked)"
      else
        failc "D1" "scaffolded file missing: $_dest"
      fi
      ;;
    *)
      failc "D1" "unknown artifact kind '$_kind' for $_dest"
      ;;
  esac
  _i=$((_i + 1))
done

# ── D2: version skew (installed manifest stamp vs plugin pin) ──────────────────
echo "== D2: version skew (manifest stamp vs plugin pin) =="
_mver=$(jq -r '.version // "null"' "$MANIFEST")
_plugin_json=""
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -f "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json" ]; then
  _plugin_json="${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"
fi
if [ -n "$_plugin_json" ]; then
  _pver=$(jq -r '.version // "null"' "$_plugin_json")
  if [ "$_mver" = "$_pver" ]; then
    pass "D2: manifest version ($_mver) matches plugin pin"
  else
    failc "D2" "version skew: manifest=$_mver plugin=$_pver"
  fi
else
  skipc "D2" "plugin root not locally resolvable (CLAUDE_PLUGIN_ROOT) — version skew check deferred (E-type)"
fi

# ── D3: hook / state-root invariant ───────────────────────────────────────────
# The installed settings wiring must not resolve .autoflow state from the plugin
# root; state lives under CLAUDE_PROJECT_DIR (docs/tool-delivery-contract.md R4).
echo "== D3: state-root invariant (state resolves from CLAUDE_PROJECT_DIR) =="
_settings_file="$TARGET_ROOT/.claude/settings.json"
if [ -f "$_settings_file" ] && grep -F 'CLAUDE_PLUGIN_ROOT' "$_settings_file" 2>/dev/null | grep -qF '.autoflow'; then
  failc "D3" "settings wiring resolves .autoflow state from the plugin root (must use the project dir)"
else
  pass "D3: settings wiring does not bind .autoflow state to the plugin root"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo "=============================================="
printf 'RESULT: drift-check %d failed, %d skipped\n' "$FAIL_COUNT" "$SKIP_COUNT"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
exit 0
