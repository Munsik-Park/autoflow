#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# green-tree-register.sh — the ONE writer of a Green-tree certificate, and the
# query surface the tree-identity predicate's shared arm is answered from.
# =============================================================================
# ONE WRITER FOR BOTH STORES. A Green certificate is recorded twice — on the
# issue's own decision ledger and in the repo-scoped shared store — and two
# hand-written entries in two files is two chances to drift, with the drift
# invisible until a wrong inheritance fires. `--append` writes both, from one
# capture point, naming the same suites with the same input hashes.
#
# Usage:
#   green-tree-register.sh --append --root <dir> --ledger <path> --issue <N> \
#                          --cycle <C> --runner "<PHASE> step <S>" \
#                          --tree <hash> --head <hash> --result "<line>" \
#                          --suites "<path> [<path> ...]"
#   green-tree-register.sh --match  --root <dir> [--cover-enumerated]
#   green-tree-register.sh --store-path --root <dir>
#   green-tree-register.sh --prune  --root <dir> [--keep <n>]
#
# Exit: 0 normal, 1 refusal or no match, 2 usage, 65 when the store resolves
#       inside the repository tree (the archive path's own refusal code — it is
#       literally the same guard, called rather than mirrored).
## =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLEANUP_WRAPPER="$SCRIPT_DIR/../cleanup/cleanup-issue.sh"
SELF="$SCRIPT_DIR/green-tree-register.sh"

# The suite header grammar and the Actions `paths:` dialect (`glob_matches`)
# live in one place; the shared store, its parsing, its atomic append, its
# prune, and `suite_input_hash` live in another. Both are CALLED here, never
# re-typed — the same single-definition-site rule the closure they implement
# rests on.
# shellcheck source=scripts/test/suite-manifest.sh
. "$SCRIPT_DIR/suite-manifest.sh"
# shellcheck source=scripts/test/green-tree-store.sh
. "$SCRIPT_DIR/green-tree-store.sh"

# Default retention for `--prune`, and therefore for the prune `--append`
# performs after every write (DISPATCH directive D8). Every resolver call parses
# the whole shared store, so unbounded growth is a cost every later issue pays.
GREEN_TREE_KEEP_DEFAULT=200

# ===========================================================================
# Production subcommands
# ===========================================================================

usage() {
  echo "green-tree-register: usage:" >&2
  echo "  --append --root <dir> --ledger <path> --issue <N> --cycle <C> --runner <text> \\" >&2
  echo "           --tree <hash> --head <hash> --result <line> --suites <paths>" >&2
  echo "  --match --root <dir> [--cover-enumerated]" >&2
  echo "  --store-path --root <dir>" >&2
  echo "  --prune --root <dir> [--keep <n>]" >&2
  exit 2
}

# resolve_store <root> — fills $STORE with the shared register path and returns
# 0, or leaves it empty and RETURNS the shipped guard's own refusal code (65
# inside the repo tree). It sets a variable rather than printing one because a
# `$( … )` capture would run the resolution in a subshell, where a refusal exit
# would end the subshell and leave the caller running on an empty path — the
# refusal must reach the caller, not the capture.
STORE=""
resolve_store() {
  local rc
  STORE="$(green_tree_store_path "$1")"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    STORE=""
    [ "$rc" -eq 65 ] || echo "green-tree-register: cannot resolve the shared store for $1" >&2
    return "$rc"
  fi
  return 0
}

# capture <root> — fills CAP_DIRTY / CAP_TREE / CAP_HEAD at ONE instant, from
# the repository root, foreground: the capture point the guide defines.
capture() {
  CAP_DIRTY="$(cd "$1" && git status --porcelain 2>/dev/null)"
  CAP_TREE="$(cd "$1" && git rev-parse "HEAD^{tree}" 2>/dev/null)"
  CAP_HEAD="$(cd "$1" && git rev-parse HEAD 2>/dev/null)"
}

# capture_tree <root> — fills CAP_TREE alone. do_match's match-point compares
# only the tree, so it uses this instead of capture(): the full capture's
# CAP_DIRTY/CAP_HEAD would be computed and discarded on every match call.
capture_tree() {
  CAP_TREE="$(cd "$1" && git rev-parse "HEAD^{tree}" 2>/dev/null)"
}

head_resolves_at() { # <root> <head hash>
  (cd "$1" && git rev-parse --verify -q "$2^{commit}" >/dev/null 2>&1)
}

# entry_text <var name> <marker-line> <tree> <head> <suites> <result> <authority>
# Assigns through `printf -v` rather than returning through `$( … )`: command
# substitution strips trailing newlines, and the entry's terminating blank line
# is part of the grammar, not whitespace.
entry_text() {
  printf -v "$1" '%s\n- tree: %s\n- head: %s\n- worktree: clean\n- suites: %s\n- result: %s\n- authority: %s\n\n' \
    "$2" "$3" "$4" "$5" "$6" "$7"
}

# ---------------------------------------------------------------------------
# --append — a minted certificate describes the tree that actually ran.
#
# The capture point is RE-TAKEN here and compared against the values the caller
# recorded before the suites started. That closes the window between the run and
# the write, and turns the guide's prose suppression rule into a mechanical
# refusal: a dirty worktree, or a tree/head that has moved, means the tree the
# certificate would name is not the tree anything was observed over. On either,
# NEITHER store is written.
#
# The ledger is written first and the shared store second, and the order is not
# arbitrary: the ledger is the record with authority, so a failure to write it
# must leave the cache untouched rather than the other way round.
# ---------------------------------------------------------------------------
do_append() {
  local store tokens s h ledger_entry shared_entry
  [ -n "$OPT_LEDGER" ] && [ -n "$OPT_ISSUE" ] && [ -n "$OPT_CYCLE" ] && [ -n "$OPT_RUNNER" ] \
    && [ -n "$OPT_TREE" ] && [ -n "$OPT_HEAD" ] && [ -n "$OPT_RESULT" ] && [ -n "$OPT_SUITES" ] || usage
  resolve_store "$ROOT" || exit $?
  store="$STORE"

  capture "$ROOT"
  if [ -n "$CAP_DIRTY" ]; then
    echo "green-tree-register: refusing to append — the worktree is dirty at write time, so the certificate would name a tree nothing ran over" >&2
    exit 1
  fi
  if [ "$CAP_TREE" != "$OPT_TREE" ]; then
    echo "green-tree-register: refusing to append — the observed tree ($CAP_TREE) differs from the recorded one ($OPT_TREE)" >&2
    exit 1
  fi
  if [ "$CAP_HEAD" != "$OPT_HEAD" ]; then
    echo "green-tree-register: refusing to append — the observed head ($CAP_HEAD) differs from the recorded one ($OPT_HEAD)" >&2
    exit 1
  fi

  # Each named suite is keyed at the VERIFIED tree. A suite whose ci-subject
  # header cannot be read has no closure, so it is recorded in the shipped bare
  # form: it still folds, and the input-hash short-circuit simply cannot fire on
  # it — the fail-safe direction.
  tokens=""
  for s in $OPT_SUITES; do
    [ -n "$s" ] || continue
    h="$(suite_input_hash "$ROOT" "$CAP_TREE" "$s" 2>/dev/null || true)"
    if [ -n "$h" ]; then
      tokens="$tokens${tokens:+ }$s@$h"
    else
      tokens="$tokens${tokens:+ }$s"
    fi
  done

  entry_text ledger_entry \
    "### green-tree | cycle: $OPT_CYCLE | runner: $OPT_RUNNER" \
    "$CAP_TREE" "$CAP_HEAD" "$tokens" "$OPT_RESULT" "Green-tree register"
  entry_text shared_entry \
    "### green-tree-shared | issue: #$OPT_ISSUE | cycle: $OPT_CYCLE | runner: $OPT_RUNNER" \
    "$CAP_TREE" "$CAP_HEAD" "$tokens" "$OPT_RESULT" "Green-tree register (shared store)"

  if ! green_tree_store_append "$OPT_LEDGER" "$ledger_entry"; then
    echo "green-tree-register: the ledger write could not complete; neither store was changed" >&2
    exit 1
  fi
  if ! green_tree_store_append "$store" "$shared_entry"; then
    echo "green-tree-register: the shared-store write could not complete" >&2
    exit 1
  fi
  green_tree_store_prune "$store" "$OPT_KEEP" || true
  return 0
}

# ---------------------------------------------------------------------------
# --match — the tree-identity predicate's SHARED ARM.
#
# A shared entry QUALIFIES when its `tree` equals the captured tree, its
# `result` is a pass, and its `head` resolves. Each qualifying entry's heading
# is printed, one per line; nothing is printed and the exit is non-zero when
# none qualifies.
#
# Under --cover-enumerated the coverage test applies to the UNION of the
# qualifying entries' `suites` fields, and the entries printed are those
# contributing at least one enumerated suite to that union. The union is not a
# convenience: certificates are minted per phase-step run naming the suites THAT
# run executed, so two issues at one tree ordinarily leave two partial entries,
# and joint coverage is the ordinary cross-issue case. It is also the rule the
# resolver's own shared arm applies — under a single-covering-entry rule the
# resolver would plan nothing while this predicate reported a mismatch, which is
# `outcome: inherited` with a non-`none` cause, forbidden as a biconditional.
# ---------------------------------------------------------------------------
do_match() {
  local store kind heading e_tree e_head e_suites e_result tok path
  resolve_store "$ROOT" || exit $?
  store="$STORE"
  capture_tree "$ROOT"
  [ -n "$CAP_TREE" ] || return 1

  local -a q_headings=() q_suites=()
  while IFS=$'\t' read -r kind heading e_tree e_head e_suites e_result; do
    [ "$kind" = OK ] || continue
    [ "$e_tree" = "$CAP_TREE" ] || continue
    entry_result_is_pass "$e_result" || continue
    head_resolves_at "$ROOT" "$e_head" || continue
    q_headings+=("$heading")
    q_suites+=("$e_suites")
  done < <(green_tree_shared_scan "$store")

  local n=${#q_headings[@]}
  [ "$n" -gt 0 ] || return 1

  if [ "$COVER_ENUMERATED" -eq 0 ]; then
    local i
    for (( i = 0; i < n; i++ )); do printf '%s\n' "${q_headings[$i]}"; done
    return 0
  fi

  # Each entry's tokens are parsed to paths ONCE here, into entry_paths[i], and
  # reused below for the contributed check — avoiding a second
  # green_tree_suite_token_path subshell per token.
  local -A covered=()
  local -a entry_paths=()
  local i paths
  for (( i = 0; i < n; i++ )); do
    paths=""
    for tok in ${q_suites[$i]}; do
      path="$(green_tree_suite_token_path "$tok")"
      if [ -n "$path" ]; then
        covered["$path"]=1
        paths="$paths${paths:+ }$path"
      fi
    done
    entry_paths[i]="$paths"
  done

  local -a enumerated=()
  while IFS= read -r path; do
    [ -n "$path" ] && enumerated+=("$path")
  done < <(suite_enumerate "$ROOT")
  [ "${#enumerated[@]}" -gt 0 ] || return 1
  for path in "${enumerated[@]}"; do
    [ -n "${covered[$path]:-}" ] || return 1
  done

  local -A is_enumerated=()
  for path in "${enumerated[@]}"; do is_enumerated["$path"]=1; done
  local contributed
  for (( i = 0; i < n; i++ )); do
    contributed=0
    for path in ${entry_paths[$i]}; do
      if [ -n "${is_enumerated[$path]:-}" ]; then contributed=1; break; fi
    done
    [ "$contributed" -eq 1 ] && printf '%s\n' "${q_headings[$i]}"
  done
  return 0
}

# ===========================================================================
# Dispatch
# ===========================================================================

MODE=""
ROOT=""
OPT_LEDGER=""; OPT_ISSUE=""; OPT_CYCLE=""; OPT_RUNNER=""
OPT_TREE=""; OPT_HEAD=""; OPT_RESULT=""; OPT_SUITES=""
OPT_KEEP="$GREEN_TREE_KEEP_DEFAULT"
COVER_ENUMERATED=0

[ $# -gt 0 ] || usage
while [ $# -gt 0 ]; do
  case "$1" in
    --append|--match|--store-path|--prune)
      [ -z "$MODE" ] || usage
      MODE="${1#--}"
      ;;
    --cover-enumerated) COVER_ENUMERATED=1 ;;
    --root)    require_value green-tree-register "$1" $# "${2:-}" || exit 2; ROOT="$2"; shift ;;
    --ledger)  require_value green-tree-register "$1" $# "${2:-}" || exit 2; OPT_LEDGER="$2"; shift ;;
    --issue)   require_value green-tree-register "$1" $# "${2:-}" || exit 2; OPT_ISSUE="$2"; shift ;;
    --cycle)   require_value green-tree-register "$1" $# "${2:-}" || exit 2; OPT_CYCLE="$2"; shift ;;
    --runner)  require_value green-tree-register "$1" $# "${2:-}" || exit 2; OPT_RUNNER="$2"; shift ;;
    --tree)    require_value green-tree-register "$1" $# "${2:-}" || exit 2; OPT_TREE="$2"; shift ;;
    --head)    require_value green-tree-register "$1" $# "${2:-}" || exit 2; OPT_HEAD="$2"; shift ;;
    --result)  require_value green-tree-register "$1" $# "${2:-}" || exit 2; OPT_RESULT="$2"; shift ;;
    --suites)  require_value green-tree-register "$1" $# "${2:-}" || exit 2; OPT_SUITES="$2"; shift ;;
    --keep)    require_value green-tree-register "$1" $# "${2:-}" || exit 2; OPT_KEEP="$2"; shift ;;
    *) echo "green-tree-register: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

[ -n "$MODE" ] || usage
[ -n "$ROOT" ] || usage
[ -d "$ROOT" ] || { echo "green-tree-register: --root is not a directory: $ROOT" >&2; exit 2; }
case "$OPT_KEEP" in ''|*[!0-9]*) echo "green-tree-register: --keep must be a non-negative integer" >&2; exit 2 ;; esac

case "$MODE" in
  store-path)
    resolve_store "$ROOT" || exit $?
    printf '%s\n' "$STORE"
    exit 0
    ;;
  append)
    do_append
    exit $?
    ;;
  match)
    do_match
    exit $?
    ;;
  prune)
    resolve_store "$ROOT" || exit $?
    green_tree_store_prune "$STORE" "$OPT_KEEP"
    exit $?
    ;;
esac
