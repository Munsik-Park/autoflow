#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# check-cycle-layer-index.sh — standing predicate: no cycle-layer asset has
# entered the merged tree.
# =============================================================================
# A `cycle`-layer asset — a `delivery-check`, a default `automated` row's test,
# a default `manual` checklist — lives under the single declared prefix
# `.autoflow/issue-{N}-local/`, is executed once, and is archived with the
# issue's other artifacts. It never enters the merged tree (ADR-0024 D2).
#
# THE SUBJECT IS THE INDEX, NOT THE WORKTREE. `.gitignore` already keeps the
# prefix out of the default add path, so a worktree predicate re-checks what the
# ignore rule does. What it cannot witness is the two DISAGREEING — a path put
# into the index over the ignore rule (`git add -f`, an ignore rule edited three
# cycles from now, a merge that carries one in) — and that disagreement is the
# whole defect, visible only after merge where no per-PR relation sees it.
# `git ls-files` reads the index, so a tracked path is found whether or not it
# is still on disk, and an on-disk path that was never added is not a finding.
#
# THE READ FORM IS `-z`, NOT THE DEFAULT. `git ls-files`'s default output is not
# the path: `core.quotePath` (default `true`) wraps any path carrying non-ASCII
# or control bytes in double quotes and octal-escapes the bytes, so a tracked
# `.autoflow/issue-9-local/검증.sh` is printed as
# `".autoflow/issue-9-local/\352\262\200\354\246\235.sh"` — which no longer
# starts with `.autoflow/` textually, so the prefix match misses it and the
# predicate answers OK. That is a false pass of exactly the disagreement this
# check exists to catch. `-z` emits raw NUL-terminated paths with no quoting at
# all, so the match is over the path itself, for every byte a path may carry.
#
# THE SCOPE IS THE DECLARED PREFIX, not `.autoflow/` as a whole: this repository
# legitimately tracks `.autoflow/.gitkeep`, and the ledger, the state file and
# the review-findings file are cycle-spanning artifacts of the store, not
# cycle-layer assets.
#
# Usage:
#   bash scripts/test/check-cycle-layer-index.sh [--root <dir>]
#
# Exit: 0 no path under the prefix is tracked (the verdict names the prefix and
#         the tree it examined, so a clean answer is distinguishable from one
#         that examined nothing);
#       1 at least one is — every offending path is named, not only the first;
#       2 the question could not be answered (usage, or a root that is not a git
#         repository). A not-run is never rendered as a pass (ADR-0024 D1).
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=scripts/test/suite-manifest.sh
. "$SCRIPT_DIR/suite-manifest.sh"

# The prefix, as one literal and one pattern derived from it. Both are here
# rather than in two callers: the declared prefix is ADR-0024 D2's, and a second
# spelling of it is a second declaration.
CYCLE_LAYER_PREFIX='.autoflow/issue-{N}-local/'
CYCLE_LAYER_RE='^\.autoflow/issue-[^/]+-local/'

ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) require_value check-cycle-layer-index "$1" $# "${2:-}" || exit 2; ROOT="$2"; shift ;;
    *)      echo "check-cycle-layer-index: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done
ROOT="${ROOT:-$DEFAULT_ROOT}"

if [ ! -d "$ROOT" ]; then
  echo "check-cycle-layer-index: --root is not a directory: $ROOT" >&2
  exit 2
fi

# Anchored on the repository's own top level, so the answer is about the whole
# index rather than about whichever subdirectory the caller happened to name.
TOP="$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$TOP" ]; then
  echo "check-cycle-layer-index: $ROOT is not inside a git repository — the index is the subject, so there is nothing to read" >&2
  echo "  Unanswerable is reported as unanswerable: a silent 0 here would be a pass this check never earned." >&2
  exit 2
fi

TRACKED=""
TRACKED_COUNT=0
while IFS= read -r -d '' INDEX_PATH; do
  [[ "$INDEX_PATH" =~ $CYCLE_LAYER_RE ]] || continue
  TRACKED="${TRACKED}${INDEX_PATH}"$'\n'
  TRACKED_COUNT=$((TRACKED_COUNT + 1))
done < <(git -C "$TOP" ls-files -z -- '.autoflow' 2>/dev/null)

if [ "$TRACKED_COUNT" -eq 0 ]; then
  echo "check-cycle-layer-index: OK — no path under $CYCLE_LAYER_PREFIX is tracked in $TOP"
  exit 0
fi

echo "check-cycle-layer-index: $TRACKED_COUNT cycle-layer asset(s) tracked under $CYCLE_LAYER_PREFIX in $TOP"
printf '%s' "$TRACKED" | sed 's/^/  /'
echo "  A cycle-layer asset is uncommitted by rule (ADR-0024 D2): it is executed once and archived with the issue's other .autoflow artifacts."
echo "  Remove it from the index ('git rm --cached <path>'), and check that .gitignore still excludes the prefix — the two disagreeing is what this predicate exists to catch."
exit 1
