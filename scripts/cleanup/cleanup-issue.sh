#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
# scripts/cleanup/cleanup-issue.sh
#
# AutoFlow's record function — MARKS an attempt that is over COMPLETED in its
# record directory `<record-root>/<repo-key>/<stamp>-issue-<N>/` (issues #423,
# #466; scripts/lib/records.sh). The records stay where they are: the record
# root is outside every checkout's tree from the start, so nothing is moved,
# copied or archived. It DELETES exactly one path, the cycle-layer store's
# reserved top-level entry `issue-<N>-local/disposable` (reproducible output —
# ADR-0024 D2), and then writes the mark `completed`; nothing else is deleted.
# It touches no git ref, no remote and no pull request.
#
# Its precondition: an attempt that is not active (no state file, or one whose
# `active` is not `true`) and whose PR is merged or closed. The script does not
# read the state file, so the caller holds the precondition; whether and when
# the script runs is the operator's practice. Only THIS checkout's attempt is
# marked — the one whose
# `checkout` file names this checkout: an attempt whose checkout is gone is
# left as it is until another checkout takes it over (`autoflow-records claim`),
# and another live checkout's attempt is never touched (issue #466 AC4).
#
# WHY A SCRIPT (not a bare `rm`): the cleanup is invoked by PATH, so the Bash
# command carries no `rm` token. Claude Code permission precedence is deny >
# allow, so an `rm` allow-exception CANNOT override a broad `rm` deny (e.g.
# `Bash(rm:*)`) — the deny always wins. A non-`rm` wrapper is never matched by
# an rm deny, so this lets a broad rm deny coexist with AutoFlow cleanup. The
# one internal `rm` removes only the reserved path above, and a permission rule
# matches the invoked command, not it.
#
# BRANCH BOUNDARY: an attempt is named by its dev branch, whose shape
# `dev-YYYY-MM-DD-HHMMSS-issue-<N>` (`dev/…` before issue #490) is checked
# before it is turned into its record directory's name — so no glob, slash or
# `..` reaches a path, and another repository's attempt (a different
# <repo-key>) is never taken.
#
# Allow-list (so it never prompts even when rm is denied):
#   "Bash(<autoflow-root>/scripts/cleanup/cleanup-issue.sh:*)"
#
# Exit codes:
#   0   every named attempt marked (or already marked)
#   1   an attempt not marked — not this checkout's, no record, or the reserved
#       path could not be deleted; the line says which
#   7   the record root is undetermined or unusable (the marker line says why)
#   64  usage
#
# Usage:
#   scripts/cleanup/cleanup-issue.sh <dev branch> [<dev branch> ...]
set -uo pipefail

# shellcheck source=scripts/lib/records.sh
. "$(dirname "$0")/../lib/records.sh"

if [ "$#" -eq 0 ]; then
  echo "usage: $0 <dev branch> [<dev branch> ...]" >&2
  exit 64
fi

TOP="$(af_checkout_top .)" || { echo "refuse: not inside a git checkout" >&2; exit 64; }
if ! af_record_root "$TOP" || ! af_record_root_ensure; then
  af_record_root_marker >&2
  exit "$AF_RECORD_ROOT_EXIT"
fi
KEY="$(autoflow_repo_key "$TOP")"
NOW="$(date +%FT%T%z)"

status=0
for B in "$@"; do
  if ! A="$(af_attempt_key "$B")"; then
    echo "refuse: '$B' is not an attempt's dev branch (dev-YYYY-MM-DD-HHMMSS-issue-N)" >&2
    status=64
    continue
  fi
  N="$(af_attempt_issue "$A")"
  d="$AF_RECORD_ROOT/$KEY/$A"
  if [ ! -d "$d" ]; then
    echo "attempt $A: no record directory $d — nothing to mark" >&2
    status=1
    continue
  fi
  owner=""
  [ -f "$d/checkout" ] && { IFS= read -r owner < "$d/checkout" || true; }
  if [ "$owner" != "$TOP" ]; then
    echo "attempt $A: belongs to the checkout ${owner:-(none recorded)}, not this one ($TOP) — not marked; a checkout that is gone is taken over first (autoflow-records claim)" >&2
    status=1
    continue
  fi
  if [ -e "$d/completed" ]; then
    echo "attempt $A: already marked completed"
    continue
  fi

  # The reserved path is deleted before the mark is written: a failed deletion
  # then leaves the attempt unmarked, and its re-run starts from the same state.
  # `-e` alone misses a dangling link. `rm -r` removes a link at or under the
  # operand without following it, as long as the operand carries no trailing
  # slash. A store that is itself a link keeps its target untouched.
  local_store="$d/issue-${N}-local"
  note=""
  if [ -L "$local_store" ]; then
    note="skipped deleting issue-${N}-local/disposable (the store is a symbolic link); "
  elif [ -d "$local_store" ]; then
    reserved="$local_store/disposable"
    if [ -e "$reserved" ] || [ -L "$reserved" ]; then
      if ! rm -rf "$reserved"; then
        echo "attempt $A: could not delete issue-${N}-local/disposable — not marked" >&2
        status=1
        continue
      fi
      note="deleted issue-${N}-local/disposable; "
    fi
  fi

  if ! printf 'completed: %s\nbranch: %s\ncheckout: %s\n' "$NOW" "$B" "$TOP" > "$d/completed"; then
    echo "attempt $A: could not write $d/completed" >&2
    status=1
    continue
  fi
  echo "attempt $A: ${note}marked completed — $d"
done

exit "$status"
