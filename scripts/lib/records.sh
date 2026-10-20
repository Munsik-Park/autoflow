#!/bin/sh
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
# =============================================================================
# records.sh — the record root, the repository key and an attempt's record
# directory (issues #423, #466)
# =============================================================================
# POSIX sh, SOURCED (never executed). Every file AutoFlow writes lives outside
# every checkout's working tree, under ONE record root:
#
#   <record-root>/<repo-key>/<stamp>-issue-<N>/   an attempt's record directory
#   <record-root>/<repo-key>/drafts/              issue drafts
#   <record-root>/<repo-key>/proposals/           proposal records
#   <record-root>/_metrics/                       cycle metrics
#   <record-root>/.ledger-check-cache             the gate hook's ledger cache
#
# An attempt is one run of an issue: its key is the name of its dev branch
# without `dev/` — `dev/<stamp>-issue-<N>` → `<stamp>-issue-<N>`, <stamp> being
# `YYYY-MM-DD-HHMMSS`. Its record directory holds the state file, the ledger,
# the reports, the criterion review record and the cycle-layer store, and the
# file `checkout`: one line, the physical path of the checkout the attempt
# belongs to (the one that started it, or took it over). `completed` marks an
# attempt whose cleanup has run (scripts/cleanup/cleanup-issue.sh).
#
# The record root is `record_root` in the operator's user file
# $HOME/.autoflow/config.json (scripts/lib/user-config.sh); the file's place
# never moves with it. No file, no key, or a JSON `null` → the default
# $HOME/.autoflow. A file that cannot be read as JSON (a syntax error, no jq),
# or a `record_root` that is not an absolute path string, leaves the record
# root UNDETERMINED — never the default in its stead (a `.` or `..` component
# included). A record root inside the session's checkout, or one that cannot be
# created or written, is UNUSABLE.
# Nothing else — no environment variable — names the root or a part of it.
#
#   af_physical_path <path>
#       the physical absolute path; a not-yet-existing tail is kept
#   af_checkout_top [<dir>]
#       the physical top-level of the checkout <dir> (default .) is in
#   af_record_root [<checkout top>]
#       sets AF_RECORD_ROOT and returns 0, or sets AF_RECORD_ROOT_STATE
#       (undetermined|unusable) and AF_RECORD_ROOT_ERROR and returns 1;
#       AF_RECORD_ROOT_CFG is the user file's path either way
#   af_record_root_ensure
#       after af_record_root: creates the root and checks it is writable;
#       returns 1 (unusable) when it cannot
#   af_record_root_marker
#       the fixed marker line of a root that is not usable:
#         record-root: UNDETERMINED <config path> — <error>
#         record-root: UNUSABLE <record root> — <error>
#   derive_repo_key <url> <root> / autoflow_repo_key <root>
#       `<owner>__<name>` from an origin URL; with an empty <url>, a path
#       encoding of <root>
#   af_attempt_key <branch>
#       the attempt key of a dev branch, or nothing (return 1) for any other
#   af_attempt_issue <key>
#       the issue number an attempt key carries
#   af_checkout_live <path> <repo-key>
#       true when <path> is still the top-level of a checkout of <repo-key>

AF_RECORD_ROOT_EXIT=7

af_physical_path() {
  case "$1" in
    /*) _afp="$1" ;;
    *)  _afp="$PWD/$1" ;;
  esac
  _aft=""
  while [ ! -d "$_afp" ] && [ "$_afp" != "/" ]; do
    _aft="/${_afp##*/}$_aft"
    _afp="${_afp%/*}"
    [ -z "$_afp" ] && _afp="/"
  done
  _afp="$(cd -P "$_afp" 2>/dev/null && pwd)" || return 1
  [ "$_afp" = "/" ] && _afp=""
  printf '%s' "${_afp}${_aft}"
}

af_checkout_top() {
  _act="$(git -C "${1:-.}" rev-parse --show-toplevel 2>/dev/null)" || return 1
  (cd -P "$_act" 2>/dev/null && pwd)
}

af_record_root() {
  AF_RECORD_ROOT=""
  AF_RECORD_ROOT_STATE=""
  AF_RECORD_ROOT_ERROR=""
  if [ -z "${HOME:-}" ]; then
    AF_RECORD_ROOT_CFG='$HOME/.autoflow/config.json'
    AF_RECORD_ROOT_STATE=undetermined
    AF_RECORD_ROOT_ERROR="HOME is not set, so the user file and the default record root have no place"
    return 1
  fi
  AF_RECORD_ROOT_CFG="$HOME/.autoflow/config.json"
  _arr="$HOME/.autoflow"
  if [ -e "$AF_RECORD_ROOT_CFG" ]; then
    if ! command -v jq >/dev/null 2>&1; then
      AF_RECORD_ROOT_STATE=undetermined
      AF_RECORD_ROOT_ERROR="jq is not installed, so the file cannot be read as JSON"
      return 1
    fi
    # One readout per call: `<kind>\t<text>`. -s takes the whole file, so an
    # empty file or two concatenated values is not one JSON object.
    if ! _arv="$(jq -rs '
        if length != 1 then "error\tthe file is not one JSON value"
        elif (.[0] | type) != "object" then "error\tthe top level is not a JSON object"
        else .[0].record_root as $r
          | if $r == null then "default\t"
            elif ($r | type) != "string" then "error\trecord_root is not a string"
            elif $r == "" then "error\trecord_root is an empty string"
            elif ($r | test("[[:cntrl:]]")) then "error\trecord_root carries a control character"
            elif ($r | startswith("/")) | not then "error\trecord_root is not an absolute path"
            elif ($r | split("/") | any(. == "." or . == "..")) then "error\trecord_root has a . or .. component"
            else "value\t" + $r end
        end' "$AF_RECORD_ROOT_CFG" 2>&1)"; then
      AF_RECORD_ROOT_STATE=undetermined
      AF_RECORD_ROOT_ERROR="not valid JSON: $(printf '%s' "$_arv" | head -1)"
      return 1
    fi
    _art="$(printf '\t')"
    case "$_arv" in
      "default$_art"*) ;;
      "value$_art"*) _arr="${_arv#value$_art}" ;;
      "error$_art"*)
        AF_RECORD_ROOT_STATE=undetermined
        AF_RECORD_ROOT_ERROR="${_arv#error$_art}"
        return 1 ;;
      *)
        AF_RECORD_ROOT_STATE=undetermined
        AF_RECORD_ROOT_ERROR="the file could not be read"
        return 1 ;;
    esac
  fi
  while [ "${_arr%/}" != "$_arr" ] && [ "$_arr" != "/" ]; do _arr="${_arr%/}"; done
  AF_RECORD_ROOT="$_arr"
  if [ -n "${1:-}" ]; then
    if ! _arp="$(af_physical_path "$_arr")"; then
      AF_RECORD_ROOT_STATE=unusable
      AF_RECORD_ROOT_ERROR="the path cannot be resolved"
      return 1
    fi
    # Inside the checkout: by the physical prefix, and by identity (`-ef`) of
    # every existing ancestor — which a case variant on a case-insensitive file
    # system, or any other spelling of the same directory, cannot escape.
    _arin=0
    case "${_arp%/}/" in "${1%/}"/*) _arin=1 ;; esac
    _arq="$_arr"
    while [ "$_arin" = 0 ] && [ -n "$_arq" ]; do
      if [ -e "$_arq" ] && [ "$_arq" -ef "$1" ]; then _arin=1; fi
      _arq="${_arq%/*}"
    done
    if [ "$_arin" = 1 ]; then
      AF_RECORD_ROOT_STATE=unusable
      AF_RECORD_ROOT_ERROR="it is inside the working tree of the checkout $1"
      return 1
    fi
  fi
  return 0
}

af_record_root_ensure() {
  if ! mkdir -p "$AF_RECORD_ROOT" 2>/dev/null || [ ! -d "$AF_RECORD_ROOT" ]; then
    AF_RECORD_ROOT_STATE=unusable
    AF_RECORD_ROOT_ERROR="the directory cannot be created"
    return 1
  fi
  if [ ! -w "$AF_RECORD_ROOT" ]; then
    AF_RECORD_ROOT_STATE=unusable
    AF_RECORD_ROOT_ERROR="the directory is not writable"
    return 1
  fi
  return 0
}

af_record_root_marker() {
  if [ "$AF_RECORD_ROOT_STATE" = unusable ]; then
    printf 'record-root: UNUSABLE %s — %s\n' "$AF_RECORD_ROOT" "$AF_RECORD_ROOT_ERROR"
  else
    printf 'record-root: UNDETERMINED %s — %s\n' "$AF_RECORD_ROOT_CFG" "$AF_RECORD_ROOT_ERROR"
  fi
}

# derive_repo_key <url> <root> — PURE normalization of an origin URL to a
# filesystem-safe key. $1 = origin URL ('' → path-encoding fallback over
# $2 = repo root, mirroring Claude Code's ~/.claude/projects/<key> scheme). The
# URL is an argument (not a live `git` call inside the function) so the
# normalization is unit-tested table-driven and hermetic.
derive_repo_key() {
  url="$1"
  if [ -n "$url" ]; then
    # Strip any run of trailing ".git"/"/" suffixes in any order until stable, so
    # a repo's key is independent of how its origin URL happens to be spelled
    # (".git", trailing "/", or the compound ".git/"). A single fixed-order pass
    # left ".git" attached on the ".git/" shape (issue #978 cycle-2 / Codex
    # Finding 1). The loop strictly shrinks $url each pass → it always terminates.
    while :; do
      case "$url" in
        *.git) url="${url%.git}" ;;
        */)    url="${url%/}"    ;;
        *)     break ;;
      esac
    done
    repo="${url##*/}"                 # last path segment          → claude-autoflow
    rest="${url%/*}"                  # everything before it
    org="${rest##*[:/]}"              # last segment bounded by ':' or '/' → my-org
    # Sanitize chain: control chars (NUL..US, DEL) are DELETED first — sed is
    # line-based and never sees an embedded newline as data (AUDIT r1, ledger
    # E15) — then remaining non-slug bytes are replaced. The emitted key is
    # always a single line over [A-Za-z0-9._-].
    printf '%s' "${org}__${repo}" | LC_ALL=C tr -d '\000-\037\177' | LC_ALL=C sed 's/[^A-Za-z0-9._-]/_/g'
  else
    printf '%s' "$2" | LC_ALL=C tr -d '\000-\037\177' | LC_ALL=C sed 's/[^A-Za-z0-9._-]/-/g'
  fi
}

autoflow_repo_key() {
  derive_repo_key "$(git -C "$1" remote get-url origin 2>/dev/null || true)" "$1"
}

af_attempt_key() {
  printf '%s\n' "$1" | grep -Eq '^dev/[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}-issue-[0-9]+$' || return 1
  printf '%s' "${1#dev/}"
}

af_attempt_issue() {
  printf '%s' "${1##*-issue-}"
}

af_checkout_live() {
  [ -n "$1" ] && [ -d "$1" ] || return 1
  _acl="$(af_checkout_top "$1")" || return 1
  [ "$_acl" = "$1" ] || return 1
  [ "$(autoflow_repo_key "$1")" = "$2" ]
}
