#!/bin/sh
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# plugin-root.sh — resolve the installed AutoFlow plugin and its marketplace
# clone WITHOUT the hook-only CLAUDE_PLUGIN_ROOT variable (issues #167, #169)
# =============================================================================
# POSIX sh, SOURCED (never executed): drift-check.sh runs under /bin/sh and
# spawn-policy.sh under bash, and both ship into a consuming target, so this
# file ships with them (setup/manifest.json copy row, dest scripts/lib/).
#
# Why: `CLAUDE_PLUGIN_ROOT` exists only inside a hook's execution context. The
# two operator commands that need the plugin — drift-check's version-skew leg
# and `spawn-policy.sh check`'s agent-definition membership — are run by the
# orchestrator or the operator from a plain shell, where the variable is unset;
# both therefore degraded (D2 SKIP; `check` exit 1) on every thin-root target,
# which is how a 0.1.8 workflow bundle ran three weeks past eight upstream
# fixes with a passing drift-check (connev-llm/llmroute #595, #614).
#
# Every resolution below reads only local files under the Claude Code config
# directory (`$CLAUDE_CONFIG_DIR`, default `~/.claude` — the harness's own
# override variable) or an explicit env override; nothing here touches the
# network. All functions print ONE path on stdout at exit 0, or print nothing
# and return 1. Callers that want a diagnostic call *_candidates for the list
# of locations a resolution consults, in order.
#
#   autoflow_config_dir
#       ${CLAUDE_CONFIG_DIR:-$HOME/.claude}
#
#   autoflow_plugin_root [<project-root>] [<marketplace>] [<plugin>]
#       The directory holding `.claude-plugin/plugin.json` of the plugin the
#       harness loads for <project-root>. Order:
#         1. $CLAUDE_PLUGIN_ROOT              (hook context — authoritative)
#         2. <config>/plugins/installed_plugins.json — the entry for
#            `<plugin>@<marketplace>`: a `project` scope whose projectPath
#            equals <project-root> first, then `user` scope, then any other
#         3. <config>/plugins/cache/<marketplace>/<plugin>/<highest version>/
#       Defaults: marketplace `autoflow`, plugin `autoflow`.
#
#   autoflow_marketplace_root [<marketplace>]
#       The local clone of the marketplace repository — the tree that holds
#       setup/manifest.json and plugin/<plugin>/ (what `/autoflow:install`
#       stamps from). Order:
#         1. $AUTOFLOW_MARKETPLACE_ROOT        (explicit override; tests, CI)
#         2. <config>/plugins/known_marketplaces.json → .<marketplace>.installLocation
#         3. <config>/plugins/marketplaces/<marketplace>/
#
# Version ordering in step 3 of autoflow_plugin_root is numeric per dotted
# field (`sort -t. -kN,Nn`), which both BSD and GNU sort implement; a cache
# directory whose name is not a dotted-numeric version is ignored.
# =============================================================================

autoflow_config_dir() {
  printf '%s\n' "${CLAUDE_CONFIG_DIR:-${HOME:-}/.claude}"
}

# ── plugin root ──────────────────────────────────────────────────────────────
autoflow_plugin_root_candidates() {
  _aprc_cfg=$(autoflow_config_dir)
  _aprc_mkt="${2:-autoflow}"; _aprc_plg="${3:-autoflow}"
  printf '%s\n' \
    "\$CLAUDE_PLUGIN_ROOT (${CLAUDE_PLUGIN_ROOT:-unset})" \
    "$_aprc_cfg/plugins/installed_plugins.json (entry $_aprc_plg@$_aprc_mkt)" \
    "$_aprc_cfg/plugins/cache/$_aprc_mkt/$_aprc_plg/<version>/"
}

autoflow_plugin_root() {
  _apr_target="${1:-}"; _apr_mkt="${2:-autoflow}"; _apr_plg="${3:-autoflow}"

  # 1. Hook context.
  if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] \
     && [ -f "$CLAUDE_PLUGIN_ROOT/.claude-plugin/plugin.json" ]; then
    printf '%s\n' "$CLAUDE_PLUGIN_ROOT"
    return 0
  fi

  _apr_cfg=$(autoflow_config_dir)

  # 2. The harness's own install registry — the path it actually loads.
  _apr_reg="$_apr_cfg/plugins/installed_plugins.json"
  if [ -f "$_apr_reg" ] && command -v jq >/dev/null 2>&1; then
    _apr_path=$(jq -r --arg k "$_apr_plg@$_apr_mkt" --arg t "$_apr_target" '
      ((.plugins // {})[$k] // []) as $e
      | ( [ $e[] | select(.scope == "project" and $t != "" and .projectPath == $t) ]
        + [ $e[] | select(.scope == "user") ]
        + [ $e[] | select(.scope != "project" and .scope != "user") ] )
      | map(.installPath // empty) | .[0] // empty' "$_apr_reg" 2>/dev/null)
    if [ -n "$_apr_path" ] && [ -f "$_apr_path/.claude-plugin/plugin.json" ]; then
      printf '%s\n' "$_apr_path"
      return 0
    fi
  fi

  # 3. The versioned cache directory: highest dotted-numeric version.
  _apr_cache="$_apr_cfg/plugins/cache/$_apr_mkt/$_apr_plg"
  if [ -d "$_apr_cache" ]; then
    _apr_best=$(ls -1 "$_apr_cache" 2>/dev/null \
      | grep -E '^[0-9]+(\.[0-9]+)*$' \
      | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -n 1)
    if [ -n "$_apr_best" ] \
       && [ -f "$_apr_cache/$_apr_best/.claude-plugin/plugin.json" ]; then
      printf '%s\n' "$_apr_cache/$_apr_best"
      return 0
    fi
  fi

  return 1
}

# ── marketplace clone ────────────────────────────────────────────────────────
autoflow_marketplace_root_candidates() {
  _amrc_cfg=$(autoflow_config_dir)
  _amrc_mkt="${1:-autoflow}"
  printf '%s\n' \
    "\$AUTOFLOW_MARKETPLACE_ROOT (${AUTOFLOW_MARKETPLACE_ROOT:-unset})" \
    "$_amrc_cfg/plugins/known_marketplaces.json (entry $_amrc_mkt)" \
    "$_amrc_cfg/plugins/marketplaces/$_amrc_mkt/"
}

autoflow_marketplace_root() {
  _amr_mkt="${1:-autoflow}"

  # 1. Explicit override.
  if [ -n "${AUTOFLOW_MARKETPLACE_ROOT:-}" ] && [ -d "$AUTOFLOW_MARKETPLACE_ROOT" ]; then
    printf '%s\n' "$AUTOFLOW_MARKETPLACE_ROOT"
    return 0
  fi

  _amr_cfg=$(autoflow_config_dir)

  # 2. The harness's marketplace registry.
  _amr_reg="$_amr_cfg/plugins/known_marketplaces.json"
  if [ -f "$_amr_reg" ] && command -v jq >/dev/null 2>&1; then
    _amr_path=$(jq -r --arg m "$_amr_mkt" '.[$m].installLocation // empty' "$_amr_reg" 2>/dev/null)
    if [ -n "$_amr_path" ] && [ -d "$_amr_path" ]; then
      printf '%s\n' "$_amr_path"
      return 0
    fi
  fi

  # 3. The conventional clone location.
  _amr_dir="$_amr_cfg/plugins/marketplaces/$_amr_mkt"
  if [ -d "$_amr_dir" ]; then
    printf '%s\n' "$_amr_dir"
    return 0
  fi

  return 1
}
