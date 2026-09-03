#!/bin/sh
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# AutoFlow thin-root drift detector (issue #792 [#785-S5], WI-3; #167)
# =============================================================================
# Target-local, network-free self-verify. Shipped into a consuming target at
# .claude/autoflow/drift-check.sh by `setup/init.sh --target`. Reads the
# installed manifest (.claude/autoflow/manifest.json) and asserts the landed
# artifacts still match it. Runs with no dependency on the AutoFlow source repo.
#
# Resolution:
#   TARGET_ROOT = ${CLAUDE_PROJECT_DIR:-<this script's ../..>}
#   Plugin root / marketplace clone: scripts/lib/plugin-root.sh (shipped with
#   this script) — $CLAUDE_PLUGIN_ROOT when set (hook context), otherwise the
#   harness's own registries under ${CLAUDE_CONFIG_DIR:-~/.claude}/plugins/.
#   Neither is required: an unresolvable one SKIPs its checks, never fails.
#
# Checks (map 1:1 to docs/tool-delivery-contract.md R4):
#   D1  manifest coverage + content drift (dispatch by artifact kind)
#   D2  version skew: installed manifest version vs the installed plugin's
#       plugin.json (SKIP when no plugin root resolves)
#   D3  hook/state-root invariant: state resolves from CLAUDE_PROJECT_DIR
#   D4  upstream drift: installed manifest vs the marketplace clone's
#       setup/manifest.json, per artifact by sha256 — catches a bundle that is
#       self-consistent (D1 PASS) but older than what the clone would stamp,
#       including upstream changes that carried no version bump (SKIP when no
#       clone resolves). A changed `scaffold` sample and an artifact upstream no
#       longer ships are WARNs: a re-stamp neither overwrites nor removes them.
#   D5  plugin skew: the installed plugin's files vs the clone's plugin source
#       (`plugin/<name>/`) — the hooks a session runs and the thin-root docs it
#       reads must come from the same source (SKIP when either side is missing)
#
# Exit: 0 = no drift (SKIP and WARN allowed); 1 = any FAIL.
#   A FAIL is a PREFLIGHT stop condition (see setup/SETUP-GUIDE.md): D1/D3 →
#   repair the installed file; D2/D4 → re-stamp from the clone
#   (`/autoflow:install`, or `<clone>/setup/init.sh --target <root> --force`;
#   refresh the clone first if it is the side that is behind); D5 → update the
#   plugin (`/plugin update <plugin>@<marketplace>`).
#
# Consumers that parse this output (plugin/autoflow/skills/install/scripts/
# detect.sh) key on the `FAIL: <id> -- ` line grammar; keep it.
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
PLUGIN_ROOT_LIB="$TARGET_ROOT/scripts/lib/plugin-root.sh"

FAIL_COUNT=0
SKIP_COUNT=0
WARN_COUNT=0
pass()  { printf 'PASS: %s\n' "$1"; }
failc() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s -- %s\n' "$1" "$2"; }
skipc() { SKIP_COUNT=$((SKIP_COUNT + 1)); printf 'SKIP: %s -- %s\n' "$1" "$2"; }
warnc() { WARN_COUNT=$((WARN_COUNT + 1)); printf 'WARN: %s -- %s\n' "$1" "$2"; }
hint()  { printf 'HINT: %s\n' "$1"; }

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

# The plugin/marketplace resolver ships as a sibling artifact. A bundle stamped
# before it existed carries a drift-check that predates this leg too, so the
# only way to reach here without it is a partial stamp — degrade to SKIP with
# the reason named, never to a silent PASS.
_lib_ok=0
if [ -f "$PLUGIN_ROOT_LIB" ]; then
  # shellcheck source=/dev/null
  . "$PLUGIN_ROOT_LIB" && _lib_ok=1
fi

# Marketplace / plugin names, read from the shipped settings pin
# (`enabledPlugins: { "<plugin>@<marketplace>": true }`); defaults otherwise.
_pin_key=""
[ -f "$PIN_REF" ] && _pin_key=$(jq -r '.enabledPlugins // {} | keys | .[0] // empty' "$PIN_REF" 2>/dev/null)
case "$_pin_key" in
  *@*) PLUGIN_NAME="${_pin_key%@*}"; MARKETPLACE_NAME="${_pin_key#*@}" ;;
  *)   PLUGIN_NAME="autoflow";        MARKETPLACE_NAME="autoflow" ;;
esac

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

# ── D2: version skew (installed manifest stamp vs installed plugin) ───────────
echo "== D2: version skew (manifest stamp vs plugin pin) =="
_mver=$(jq -r '.version // "null"' "$MANIFEST")
_plugin_root=""
_plugin_json=""
if [ "$_lib_ok" = 1 ]; then
  _plugin_root=$(autoflow_plugin_root "$TARGET_ROOT" "$MARKETPLACE_NAME" "$PLUGIN_NAME" 2>/dev/null) || _plugin_root=""
elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  _plugin_root="$CLAUDE_PLUGIN_ROOT"
fi
[ -n "$_plugin_root" ] && [ -f "$_plugin_root/.claude-plugin/plugin.json" ] \
  && _plugin_json="$_plugin_root/.claude-plugin/plugin.json"
_pver=""
if [ -n "$_plugin_json" ]; then
  _pver=$(jq -r '.version // "null"' "$_plugin_json")
  if [ "$_mver" = "$_pver" ]; then
    pass "D2: manifest version ($_mver) matches plugin pin ($_plugin_root)"
  else
    failc "D2" "version skew: manifest=$_mver plugin=$_pver ($_plugin_root)"
  fi
elif [ "$_lib_ok" = 1 ]; then
  skipc "D2" "plugin root not locally resolvable (tried: $(autoflow_plugin_root_candidates "$TARGET_ROOT" "$MARKETPLACE_NAME" "$PLUGIN_NAME" | tr '\n' ';' | sed 's/;$//; s/;/; /g')) — version skew check deferred (E-type)"
else
  skipc "D2" "plugin root not locally resolvable (CLAUDE_PLUGIN_ROOT unset and scripts/lib/plugin-root.sh not installed) — version skew check deferred (E-type)"
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

# ── D4: upstream drift (installed manifest vs marketplace clone manifest) ─────
# D1 proves the installed files equal the installed manifest; this leg proves
# the installed manifest equals what the clone would stamp today. Comparing
# per-artifact sha256 rather than `.version` is what catches an upstream change
# merged without a version bump. Row kinds decide the disposition: a `copy`,
# `shim-stamp` or `json-merge` row a re-stamp WOULD refresh is a FAIL; a
# `scaffold` row (never overwritten) or a row upstream dropped (never removed)
# is a WARN the operator disposes of by hand.
echo "== D4: upstream drift (installed bundle vs marketplace clone) =="
_clone=""
if [ "$_lib_ok" = 1 ]; then
  _clone=$(autoflow_marketplace_root "$MARKETPLACE_NAME" 2>/dev/null) || _clone=""
fi
_clone_manifest=""
[ -n "$_clone" ] && [ -f "$_clone/setup/manifest.json" ] && _clone_manifest="$_clone/setup/manifest.json"
if [ "$_lib_ok" != 1 ]; then
  skipc "D4" "marketplace clone not locally resolvable (scripts/lib/plugin-root.sh not installed) — upstream drift check deferred"
elif [ -z "$_clone" ]; then
  skipc "D4" "marketplace clone not locally resolvable (tried: $(autoflow_marketplace_root_candidates "$MARKETPLACE_NAME" | tr '\n' ';' | sed 's/;$//; s/;/; /g')) — upstream drift check deferred"
elif [ -z "$_clone_manifest" ]; then
  skipc "D4" "marketplace clone at $_clone carries no setup/manifest.json — upstream drift check deferred"
else
  _cver=$(jq -r '.version // "null"' "$_clone_manifest")
  _clone_desc="clone version $_cver at $_clone"
  _d4_tmp=$(mktemp)
  # One relation over both manifests, keyed by dest; the manifest self-entry
  # (sha256 null) is excluded on both sides.
  jq -n -r --slurpfile ins "$MANIFEST" --slurpfile up "$_clone_manifest" '
    def bykey: map(select(.sha256 != null)) | map({key: .dest, value: .}) | from_entries;
    ($ins[0].artifacts | bykey) as $i
    | ($up[0].artifacts | bykey) as $u
    | ( [ $i | keys[] | select($u[.] == null)
          | "removed-upstream\t\(.)\t\($i[.].kind)\t\($i[.].sha256)\t-" ] )
    + ( [ $u | keys[] | select($i[.] == null)
          | "new-upstream\t\(.)\t\($u[.].kind)\t-\t\($u[.].sha256)" ] )
    + ( [ $i | keys[] | select($u[.] != null and $u[.].sha256 != $i[.].sha256)
          | "changed-upstream\t\(.)\t\($i[.].kind)\t\($i[.].sha256)\t\($u[.].sha256)" ] )
    | .[]' > "$_d4_tmp" 2>/dev/null
  _d4_fail_before=$FAIL_COUNT
  if [ ! -s "$_d4_tmp" ]; then
    pass "D4: installed bundle matches the marketplace clone ($_clone_desc)"
  else
    while IFS="$(printf '\t')" read -r _rel _dest _kind _ih _uh; do
      [ -n "$_rel" ] || continue
      _ih8=$(printf '%s' "$_ih" | cut -c1-12); _uh8=$(printf '%s' "$_uh" | cut -c1-12)
      case "$_rel:$_kind" in
        changed-upstream:scaffold)
          warnc "D4" "scaffold sample changed upstream: $_dest (target-owned — a re-stamp never overwrites it; compare against $_clone/$(jq -r --arg d "$_dest" '.artifacts[] | select(.dest == $d) | .source' "$_clone_manifest") for newly required content)"
          ;;
        changed-upstream:*)
          failc "D4" "upstream drift: $_dest differs from the marketplace clone (installed=$_ih8 clone=$_uh8)"
          ;;
        new-upstream:*)
          failc "D4" "upstream drift: $_dest is shipped by the marketplace clone but absent from the installed bundle ($_kind)"
          ;;
        removed-upstream:*)
          warnc "D4" "installed artifact no longer shipped upstream: $_dest ($_kind — a re-stamp does not remove it)"
          ;;
      esac
    done < "$_d4_tmp"
    if [ "$FAIL_COUNT" -gt "$_d4_fail_before" ]; then
      hint "D4: installed manifest version $_mver vs $_clone_desc — re-stamp from the clone: /autoflow:install (or: bash $_clone/setup/init.sh --target $TARGET_ROOT --force). If the clone itself is behind upstream, refresh it first: /plugin marketplace update $MARKETPLACE_NAME"
    fi
  fi
  rm -f "$_d4_tmp"
fi

# ── D5: plugin skew (installed plugin vs marketplace clone plugin source) ─────
# Same-release consistency between the two delivery channels: the hooks the
# session runs (plugin cache) and the docs/workflows it reads (thin root, D4)
# must both equal the clone. Only the clone's files are enumerated — the cache
# may carry loader bookkeeping of its own (e.g. `.in_use`), which is not skew.
echo "== D5: plugin skew (installed plugin vs marketplace clone plugin source) =="
_clone_plugin=""
if [ -n "$_clone" ] && [ -f "$_clone/.claude-plugin/marketplace.json" ]; then
  _psrc=$(jq -r --arg p "$PLUGIN_NAME" '.plugins[] | select(.name == $p) | .source // empty' "$_clone/.claude-plugin/marketplace.json" 2>/dev/null | head -n 1)
  [ -n "$_psrc" ] && [ -d "$_clone/$_psrc" ] && _clone_plugin=$(CDPATH= cd -- "$_clone/$_psrc" && pwd)
fi
if [ "$_lib_ok" != 1 ]; then
  skipc "D5" "plugin skew check deferred (scripts/lib/plugin-root.sh not installed)"
elif [ -z "$_plugin_root" ] || [ -z "$_plugin_json" ]; then
  skipc "D5" "installed plugin root not locally resolvable — plugin skew check deferred"
elif [ -z "$_clone" ]; then
  skipc "D5" "marketplace clone not locally resolvable — plugin skew check deferred"
elif [ -z "$_clone_plugin" ]; then
  skipc "D5" "marketplace clone at $_clone declares no plugin source for '$PLUGIN_NAME' in .claude-plugin/marketplace.json — plugin skew check deferred"
else
  _d5_fail_before=$FAIL_COUNT
  _d5_tmp=$(mktemp)
  (CDPATH= cd -- "$_clone_plugin" && find . -type f | sed 's|^\./||' | LC_ALL=C sort) > "$_d5_tmp"
  while IFS= read -r _relf; do
    [ -n "$_relf" ] || continue
    if [ ! -f "$_plugin_root/$_relf" ]; then
      failc "D5" "plugin skew: $_relf is in the marketplace clone's plugin source but not in the installed plugin ($_plugin_root)"
    elif [ "$(sha256_of "$_clone_plugin/$_relf")" != "$(sha256_of "$_plugin_root/$_relf")" ]; then
      failc "D5" "plugin skew: $_relf differs between the installed plugin ($_plugin_root) and the marketplace clone"
    fi
  done < "$_d5_tmp"
  rm -f "$_d5_tmp"
  if [ "$FAIL_COUNT" -eq "$_d5_fail_before" ]; then
    pass "D5: installed plugin ($_pver at $_plugin_root) matches the marketplace clone's plugin source"
  else
    hint "D5: installed plugin $_pver at $_plugin_root vs clone plugin source $_clone_plugin — update the plugin: /plugin update $PLUGIN_NAME@$MARKETPLACE_NAME (a thin-root re-stamp does not change the plugin)"
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo "=============================================="
printf 'RESULT: drift-check %d failed, %d skipped, %d warned\n' "$FAIL_COUNT" "$SKIP_COUNT" "$WARN_COUNT"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
exit 0
