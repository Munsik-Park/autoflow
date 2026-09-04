#!/bin/sh
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# /autoflow:install — resolve the marketplace clone the skill reads from
# Issue #174 — the plugin root's grandparent is not the clone under /plugin install
# =============================================================================
# Prints ONE path on stdout at exit 0: the local marketplace clone — the tree
# holding setup/manifest.json, setup/init.sh and setup/thin-root-layer/, which
# SKILL.md Step 1 detects against (detect.sh's PLUGIN_CACHE_ROOT) and Step 4
# stamps from (init.sh). Prints nothing on stdout, and the candidate list on
# stderr, at exit 1 when no candidate holds setup/manifest.json.
#
#   resolve-cache-root.sh [<marketplace>]         resolve (default: autoflow)
#   resolve-cache-root.sh --candidates [<mkt>]    list the locations consulted,
#                                                 in order, one per line
#
# Why not ${CLAUDE_PLUGIN_ROOT}/../.. — the derivation SKILL.md Step 0 carried
# from 0.1.0 through 0.1.9: that arithmetic holds only when the harness loads
# the plugin from inside a marketplace clone (`plugin/autoflow/` sits two
# levels below the clone root — the development channel). Under
# `/plugin install autoflow@autoflow`, the one channel a consuming target has,
# the harness copies the plugin to
# <config>/plugins/cache/<marketplace>/<plugin>/<version>/ (the
# installed_plugins.json `installPath`; Claude Code 2.1.260), whose grandparent
# is cache/<marketplace>/ and holds no setup/ at all — so detect.sh hard-errored
# before its Step 1 report on every marketplace-installed target.
#
# Candidate order: scripts/lib/plugin-root.sh's autoflow_marketplace_root — the
# resolver drift-check D4/D5 and `spawn-policy.sh check` already use (#167,
# #169) — first, and the development-channel arithmetic LAST:
#   1. $AUTOFLOW_MARKETPLACE_ROOT                        (explicit override)
#   2. <config>/plugins/known_marketplaces.json → .<marketplace>.installLocation
#   3. <config>/plugins/marketplaces/<marketplace>/
#   4. ${CLAUDE_PLUGIN_ROOT}/../..                        (a clone loaded directly)
# where <config> is ${CLAUDE_CONFIG_DIR:-$HOME/.claude}. The library returns the
# first of 1–3 that exists as a directory; this script then requires
# setup/manifest.json there, falls through to 4 when it is absent, and names
# the resolved-but-unusable directory in the failure diagnostic (a partial
# clone is repaired by `/plugin marketplace update`, not guessed around).
#
# The library is sourced from THIS script's own tree — lib/plugin-root.sh, a
# byte-identical copy of scripts/lib/plugin-root.sh whose parity
# tests/plugin/verify-package.sh pins — because the plugin cache carries no
# scripts/lib/ and an uninstalled target has none either. Nothing here touches
# the network; every read is a local file under <config>.
# =============================================================================

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LIB="$SCRIPT_DIR/lib/plugin-root.sh"

MODE=resolve
if [ "${1:-}" = "--candidates" ]; then
  MODE=candidates
  shift
fi
MKT="${1:-autoflow}"

if [ ! -f "$LIB" ]; then
  echo "ERROR: resolver library missing beside this script: $LIB" >&2
  exit 1
fi
# shellcheck source=lib/plugin-root.sh
. "$LIB"

# 4. Development channel, normalized; empty unless CLAUDE_PLUGIN_ROOT names a
#    directory (the loader inline-substitutes it inside the skill body, and a
#    hook exports it; a plain shell leaves it unset).
_dev=""
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -d "$CLAUDE_PLUGIN_ROOT" ]; then
  _dev=$(CDPATH= cd -- "$CLAUDE_PLUGIN_ROOT/../.." 2>/dev/null && pwd) || _dev=""
fi

candidates() {
  autoflow_marketplace_root_candidates "$MKT"
  printf '%s\n' "\$CLAUDE_PLUGIN_ROOT/../.. (${_dev:-unset})"
}

if [ "$MODE" = candidates ]; then
  candidates
  exit 0
fi

# 1–3: the harness's own registries, in the library's order.
_root=$(autoflow_marketplace_root "$MKT" 2>/dev/null) || _root=""
if [ -n "$_root" ] && [ -f "$_root/setup/manifest.json" ]; then
  printf '%s\n' "$_root"
  exit 0
fi

# 4: the development channel.
if [ -n "$_dev" ] && [ -f "$_dev/setup/manifest.json" ]; then
  printf '%s\n' "$_dev"
  exit 0
fi

echo "ERROR: marketplace clone for '$MKT' not resolvable — no candidate holds setup/manifest.json" >&2
if [ -n "$_root" ]; then
  echo "  resolved but unusable (no setup/manifest.json — refresh it: /plugin marketplace update $MKT): $_root" >&2
fi
echo "  tried, in order:" >&2
candidates | sed 's/^/    /' >&2
echo "  remedy: /plugin marketplace add Munsik-Park/autoflow (creates the clone), or export AUTOFLOW_MARKETPLACE_ROOT=<clone root>" >&2
exit 1
