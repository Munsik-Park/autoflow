#!/bin/sh
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
# =============================================================================
# prerequisites.sh — what the SessionStart hook checks of docs/requirements.md
# (issue #553, ADR-0041)
# =============================================================================
# POSIX sh, SOURCED (never executed). The values below restate
# docs/requirements.md, which a script does not parse;
# tests/plugin/verify-package.sh (AC6) fails when the two differ.
#
#   autoflow_missing_tools
#       prints the required tools not found on PATH, one per line
#   autoflow_claude_version
#       prints the version of the `claude` on PATH as N.N.N; prints nothing
#       when it cannot be read
#   autoflow_version_lt <a> <b>
#       0 when N.N.N version a is lower than b; any other input is not lower
#   autoflow_prerequisite_notice <requirements-doc-path>
#       prints one line naming what is missing or too old, nothing when nothing
#       is found. A version that cannot be read is not reported: it is no
#       finding that the version is low.

AUTOFLOW_REQUIRED_TOOLS='jq gh'
AUTOFLOW_MIN_CLAUDE_VERSION='2.1.277'
# Seconds `claude --version` may take before the check gives it up: a hook that
# reaches its own timeout (600 by default) would hold the session start.
AUTOFLOW_VERSION_READ_LIMIT=5

autoflow_missing_tools() {
  for _af_tool in $AUTOFLOW_REQUIRED_TOOLS; do
    command -v "$_af_tool" >/dev/null 2>&1 || printf '%s\n' "$_af_tool"
  done
}

# _autoflow_read_version <command>: the command's --version output as N.N.N.
# The output goes to a file, not a pipe: a process the command left behind
# cannot hold the reader open. The form is matched in full, so another program's
# --version reads as no version.
_autoflow_read_version() {
  _af_out="$(mktemp "${TMPDIR:-/tmp}/autoflow-version.XXXXXX" 2>/dev/null)" || return 0
  "$1" --version >"$_af_out" 2>/dev/null </dev/null &
  _af_pid=$!
  ( sleep "$AUTOFLOW_VERSION_READ_LIMIT"; kill "$_af_pid" ) >/dev/null 2>&1 </dev/null &
  _af_watchdog=$!
  wait "$_af_pid" 2>/dev/null
  kill "$_af_watchdog" 2>/dev/null
  _af_first='' _af_rest=''
  read -r _af_first _af_rest <"$_af_out" 2>/dev/null
  rm -f "$_af_out"
  case "$_af_rest" in '(Claude Code)'*) ;; *) return 0 ;; esac
  case "$_af_first" in
    *[!0-9.]*) return 0 ;;
    [0-9]*.[0-9]*.[0-9]*) printf '%s\n' "$_af_first" ;;
  esac
}

autoflow_claude_version() {
  _af_cmd="$(command -v claude 2>/dev/null)"
  [ -n "$_af_cmd" ] || return 0
  _autoflow_read_version "$_af_cmd"
}

# A malformed field makes `[` fail, which reads as not lower.
autoflow_version_lt() {
  _af_a="$1" _af_b="$2"
  for _af_i in 1 2 3; do
    _af_x="${_af_a%%.*}" _af_y="${_af_b%%.*}"
    [ "$_af_x" -lt "$_af_y" ] 2>/dev/null && return 0
    [ "$_af_x" -gt "$_af_y" ] 2>/dev/null && return 1
    _af_a="${_af_a#*.}" _af_b="${_af_b#*.}"
  done
  return 1
}

autoflow_prerequisite_notice() {
  _af_found=''
  _af_missing=''
  for _af_name in $(autoflow_missing_tools); do
    _af_missing="${_af_missing:+$_af_missing, }$_af_name"
  done
  if [ -n "$_af_missing" ]; then
    _af_found="not found on PATH: $_af_missing."
    case " $_af_missing," in
      *' jq,'*) _af_found="$_af_found Without jq the gate hook does not check a ledger write." ;;
    esac
  fi
  _af_seen="$(autoflow_claude_version)"
  if [ -n "$_af_seen" ] && autoflow_version_lt "$_af_seen" "$AUTOFLOW_MIN_CLAUDE_VERSION"; then
    _af_found="${_af_found:+$_af_found }Claude Code $_af_seen is older than the minimum, $AUTOFLOW_MIN_CLAUDE_VERSION."
  fi
  [ -n "$_af_found" ] || return 0
  printf 'AutoFlow requirements not met — %s See %s.\n' "$_af_found" "$1"
}
