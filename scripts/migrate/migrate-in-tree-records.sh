#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# scripts/migrate/migrate-in-tree-records.sh
#
# Moves the cycle records a target kept inside its own tree, under
# `.autoflow/<repo-key>-issue-<N>/` (issues #423 to #465), to the record root
# (issue #466; scripts/lib/records.sh), so a cycle in progress or waiting
# continues from there. Until it runs, the gate hook refuses score-gated calls
# on such a state file and PREFLIGHT stops (`entry: stop in-tree-records`).
#
# For each `.autoflow/<repo-key>-issue-<N>/` holding a state file
# `issue-<N>.json` whose `branch` names a dev branch `dev/<stamp>-issue-<N>`:
# the whole directory is moved to `<record-root>/<repo-key>/<stamp>-issue-<N>/`
# — the attempt record directory of that branch — and its `checkout` file is
# written with this checkout, the one the cycle ran in. The move is a rename of
# the directory (`mv`; a copy and unlink across filesystems), never a merge: a
# destination that exists is refused.
#
# A state file that names no branch, or a branch of the pre-#433 shape
# `dev/<date>-issue-<N>` (no time), gives no attempt key. When it reads
# `active: false` the cycle is not in progress: its directory is moved to
# `<record-root>/<repo-key>/in-tree-<YYYYMMDD-HHMMSS>-issue-<N>/` and marked
# `completed` — kept as a record, never entered. When it reads `active: true`
# it is not moved and is reported: the operator decides (rename the branch and
# set `branch`, or set `active: false` to leave the cycle) and runs this again.
# A directory with no state file — a proposal record, a criterion review of no
# attempt — is not a cycle, stops nothing and is left in place. Nothing else in
# `.autoflow/` is touched.
#
# Exit codes:
#   0   every cycle directory moved (or none found)
#   1   a cycle directory not moved — the line says why
#   7   the record root is undetermined or unusable (the marker line says why)
#   64  usage
#
# Usage: scripts/migrate/migrate-in-tree-records.sh [--dry-run]
set -uo pipefail

# shellcheck source=scripts/lib/records.sh
. "$(dirname "$0")/../lib/records.sh"

DRY=0
case "${1:-}" in
  '') ;;
  --dry-run) DRY=1 ;;
  *) echo "usage: $0 [--dry-run]" >&2; exit 64 ;;
esac
command -v jq >/dev/null 2>&1 || { echo "refuse: jq is not installed — the state files cannot be read" >&2; exit 64; }

TOP="$(af_checkout_top .)" || { echo "refuse: not inside a git checkout" >&2; exit 64; }
if ! af_record_root "$TOP" || ! af_record_root_ensure; then
  af_record_root_marker >&2
  exit "$AF_RECORD_ROOT_EXIT"
fi
R="$AF_RECORD_ROOT"

status=0
found=0
for d in "$TOP"/.autoflow/*-issue-*; do
  [ -d "$d" ] || continue
  base="${d##*/}"
  n="${base##*-issue-}"
  case "$n" in ''|*[!0-9]*) continue ;; esac
  key="${base%-issue-"$n"}"
  sf="$d/issue-$n.json"
  if [ ! -f "$sf" ]; then
    echo "left: .autoflow/$base/ — no state file, not a cycle (a proposal record or a criterion review of no attempt)"
    continue
  fi
  found=1
  b="$(jq -r '.branch // empty' "$sf" 2>/dev/null)"
  done_mark=""
  if ! a="$(af_attempt_key "$b")" || [ "$(af_attempt_issue "$a")" != "$n" ]; then
    if [ "$(jq -r '.active // false' "$sf" 2>/dev/null)" = true ]; then
      echo "not moved: .autoflow/$base/ — an active cycle whose state file names ${b:-no branch}, not a dev branch dev/YYYY-MM-DD-HHMMSS-issue-$n; rename the branch and set \`branch\`, or set \`active: false\` to leave the cycle, then run again" >&2
      status=1
      continue
    fi
    a="in-tree-$(date +%Y%m%d-%H%M%S)-issue-$n"
    done_mark="moved from .autoflow/$base/, a cycle not in progress that names ${b:-no branch}"
  fi
  dest="$R/$key/$a"
  if [ -e "$dest" ]; then
    echo "not moved: .autoflow/$base/ — $dest already exists" >&2
    status=1
    continue
  fi
  if [ "$DRY" = 1 ]; then
    echo "would move: .autoflow/$base/ → $dest (checkout $TOP)"
    continue
  fi
  if ! mkdir -p "$R/$key" || ! mv "$d" "$dest"; then
    echo "not moved: .autoflow/$base/ — the move to $dest failed" >&2
    status=1
    continue
  fi
  printf '%s\n' "$TOP" > "$dest/checkout"
  if [ -n "$done_mark" ]; then
    printf 'completed: %s\nnote: %s\n' "$(date +%FT%T%z)" "$done_mark" > "$dest/completed"
    echo "moved: .autoflow/$base/ → $dest (not in progress — marked completed, kept as a record)"
  else
    echo "moved: .autoflow/$base/ → $dest (checkout $TOP)"
  fi
done
[ "$found" -eq 0 ] && echo "no in-tree state file under $TOP/.autoflow/ — nothing to move"
exit "$status"
