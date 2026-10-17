#!/bin/sh
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# plugin-package.sh — copy the AutoFlow plugin package the way an install lays
# it out (sourced by the tests under tests/plugin/; never executed)
# =============================================================================
# The repository root is the plugin root (ADR-0027 D1), and an install copies
# that directory, without its .git, to
# <config>/plugins/cache/<marketplace>/<plugin>/<version>/ (issue #454 PR-3:
# `claude plugin marketplace add <clone>` + `claude plugin install
# autoflow@autoflow` under a scratch CLAUDE_CONFIG_DIR, Claude Code 2.1.302).
# The copy below takes the files git knows of — tracked, or untracked and not
# ignored — that exist in the working tree, so a test sees the package a clean
# checkout of this tree would install, local scratch (.autoflow/*) excluded.
#
#   copy_plugin_package <repo-root> <dest>   copy the package to <dest>
#   install_plugin_package <repo-root> <config-dir> [<version>]
#       copy it to the install layout under <config-dir> and print the
#       directory (what that install's CLAUDE_PLUGIN_ROOT names); <version>
#       defaults to the package's own .claude-plugin/plugin.json .version
# Plain POSIX sh + git/tar.
# =============================================================================

copy_plugin_package() {
  _cpp_src="$1"; _cpp_dst="$2"
  mkdir -p "$_cpp_dst" || return 1
  _cpp_list="$(mktemp)"
  git -C "$_cpp_src" ls-files -co --exclude-standard \
    | while IFS= read -r _cpp_f; do
        [ -f "$_cpp_src/$_cpp_f" ] && printf '%s\n' "$_cpp_f"
      done > "$_cpp_list"
  (cd "$_cpp_src" && tar -cf - -T "$_cpp_list") | (cd "$_cpp_dst" && tar -xf -)
  _cpp_rc=$?
  rm -f "$_cpp_list"
  return "$_cpp_rc"
}

install_plugin_package() {
  _ipp_src="$1"; _ipp_cfg="$2"
  _ipp_ver="${3:-$(jq -r '.version' "$_ipp_src/.claude-plugin/plugin.json")}"
  _ipp_dst="$_ipp_cfg/plugins/cache/autoflow/autoflow/$_ipp_ver"
  copy_plugin_package "$_ipp_src" "$_ipp_dst" || return 1
  printf '%s\n' "$_ipp_dst"
}
