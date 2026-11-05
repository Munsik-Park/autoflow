#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
#
# resync-submodules.sh
# ---------------------------------------------------------------------------
# Aligns, locally, a host repo's submodule "restructuring" (e.g. services/librechat → services=llmroute
# nesting) safely and idempotently across several working environments.
#
# Corrects three things `git pull --recurse-submodules` alone does not handle.
#   1) leftover old submodule sections in .git/config (names no longer in .gitmodules)
#   2) leftover working trees of old checkouts blocking an uninitialized submodule path
#   3) orphan gitdirs .git/modules/<orphan> unrelated to the current submodules
#
# It hardcodes no particular submodule name — it derives them all from .gitmodules, so
# in an already aligned environment it is a no-op, and it can be used as is for other restructurings later.
#
# Usage (run from anywhere inside the host repo):
#   bash scripts/resync-submodules.sh             # run the alignment
#   bash scripts/resync-submodules.sh --dry-run   # only print what it would do (no changes)
#   bash scripts/resync-submodules.sh --force     # discard and proceed even if the leftovers have uncommitted changes
# ---------------------------------------------------------------------------
set -euo pipefail

FORCE=0
DRY=0
for a in "$@"; do
  case "$a" in
    --force)   FORCE=1 ;;
    --dry-run) DRY=1 ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "unknown argument: $a (available: --dry-run, --force)" >&2; exit 2 ;;
  esac
done

do_git() { if [ "$DRY" = 1 ]; then echo "  DRY: git $*"; else git "$@"; fi; }
do_rm()  { if [ "$DRY" = 1 ]; then echo "  DRY: rm -rf -- $1"; else rm -rf -- "$1"; fi; }

# Positively determines whether a leftover path (p) is "clean Git residue that is safe to delete".
# Safety conditions (all met): ① at least one git working tree exists beneath it,
# ② those working trees are all clean (untracked included), and ③ there are no regular
# files outside the working trees (= the whole path is explained by git checkouts alone).
# If any one fails (= plain data with no git trace / dirty / unclassifiable files), it returns 1
# and blocks a non-force deletion. Returns 0 = safe to delete, 1 = not safe (reason on stderr).
is_removable_residue() {
  local p="$1" gitf root stray
  local roots=()
  # ① collect git working tree roots (.git matches both submodule = file / regular repo = directory)
  while IFS= read -r gitf; do
    roots+=( "$(dirname "$gitf")" )
  done < <(find "$p" -maxdepth 4 -name .git 2>/dev/null)
  if [ "${#roots[@]}" -eq 0 ]; then
    echo "    ↳ no git checkout trace — looks like a regular file/directory: $p" >&2
    return 1
  fi
  # ② check each working tree is clean (both untracked and modified)
  for root in "${roots[@]}"; do
    if [ -n "$(git -C "$root" status --porcelain 2>/dev/null)" ]; then
      echo "    ↳ uncommitted/untracked changes: $root" >&2
      return 1
    fi
  done
  # ③ check for leftover files outside the git checkouts (each root pruned → node_modules etc. not searched)
  local pruneargs=()
  for root in "${roots[@]}"; do
    pruneargs+=( -path "$root" -prune -o )
  done
  # `find … -print -quit`, NOT `find … -print | head -n 1`: under `set -o pipefail`
  # head's early exit delivers SIGPIPE to find, the pipeline's status becomes 141,
  # and `set -e` aborts this function — so a tree that merely HAS stray files is
  # reported as a resync failure rather than as the stray-file case below.
  # Measured on GNU find (the Linux runner): 100/100 aborts over a non-trivial
  # tree; BSD find on macOS does not reproduce it, which is why it stayed unseen
  # locally. `-quit` is find's own first-hit stop, so no pipe exists to break.
  stray="$(find "$p" "${pruneargs[@]}" -type f -print -quit 2>/dev/null)"
  if [ -n "$stray" ]; then
    echo "    ↳ files exist outside the git checkouts (e.g. $stray)" >&2
    return 1
  fi
  return 0
}

# ── 0. Move to the host repo root ─────────────────────────────────────────────
cd "$(git rev-parse --show-toplevel)"
echo "▶ repo: $(pwd)   (dry-run=$DRY, force=$FORCE)"

# ── 1. Update the host superproject (fast-forward only; local unmerged commits are kept) ─
branch="$(git rev-parse --abbrev-ref HEAD)"
echo "▶ host fetch ($branch)"
if [ "$DRY" = 1 ]; then
  # dry-run is a no-change contract — fetch changes .git/FETCH_HEAD and the remote-tracking refs (in particular the --prune
  # deletions), so dry-run does not run it and only prints it as a planned action.
  echo "  DRY: git fetch --prune origin"
else
  git fetch --prune origin || { echo "✗ fetch failed (check the network/remote)" >&2; exit 1; }
fi
if [ "$branch" = "HEAD" ]; then
  echo "  detached HEAD — host merge skipped (only the submodule alignment proceeds)"
elif [ "$DRY" = 1 ]; then
  echo "  DRY: git merge --ff-only origin/$branch"
elif ! git merge --ff-only "origin/$branch"; then
  echo "✗ host fast-forward failed: there may be unmerged local commits. Clean up by hand and run again." >&2
  exit 1
fi

# ── 2. Rewire .gitmodules → .git/config ───────────────────────────────────
echo "▶ submodule sync"
do_git submodule sync --recursive

# The set of submodule names in the current .gitmodules (the alignment reference)
# [MUST] zero-submodule guard: when .gitmodules is absent (= single-repo, this repo since #798)
# or has 0 submodule entries, `git config --get-regexp` returns exit 1. Under `set -euo
# pipefail` this assignment fails and the script aborts, so `|| true` is attached to the whole
# pipe to make gm_names an empty string on no-match (not an early exit — steps 3–6 after it
# still run and must clean up the old .git/config sections and the leftover orphan gitdirs). The sed normalization
# [MUST] stays: without it a gm_names entry is not a bare <name> but `submodule.<name>.path`,
# so on a multi-repo target with live submodules the grep -qxF comparison of steps 3 and 5
# mismatches and wrongly deletes active sections/gitdirs (a regression the zero-submodule oracle cannot catch).
gm_names="$(git config -f .gitmodules --name-only --get-regexp '^submodule\..*\.path$' \
            | sed -e 's/^submodule\.//' -e 's/\.path$//' || true)"

# ── 3. Remove old submodule sections from .git/config (names not in .gitmodules) ─────
echo "▶ stale .git/config section check"
cfg_names="$(git config --local --name-only --get-regexp '^submodule\..*\.url$' 2>/dev/null \
             | sed -e 's/^submodule\.//' -e 's/\.url$//' || true)"
if [ -n "$cfg_names" ]; then
  while IFS= read -r nm; do
    [ -z "$nm" ] && continue
    if ! printf '%s\n' "$gm_names" | grep -qxF "$nm"; then
      echo "  remove: submodule.$nm"
      if [ "$DRY" = 1 ]; then echo "  DRY: git config --remove-section submodule.$nm"
      else git config --local --remove-section "submodule.$nm" 2>/dev/null || true; fi
    fi
  done <<EOF
$cfg_names
EOF
fi

# ── 4. Remove leftover old working trees at uninitialized submodule paths ──────────────────
echo "▶ uninitialized path leftover check"
while IFS= read -r line; do
  [ -z "$line" ] && continue
  flag="${line:0:1}"; rest="${line:1}"
  rem="${rest#* }"; subpath="${rem%% *}"      # "<sha> <path> (desc)" → <path>
  [ "$flag" = "-" ] || continue               # '-' = uninitialized
  if [ -d "$subpath" ] && [ -n "$(ls -A "$subpath" 2>/dev/null)" ]; then
    echo "  leftover found: $subpath"
    if is_removable_residue "$subpath"; then
      do_rm "$subpath"                       # clean Git residue — safe to delete
    elif [ "$FORCE" = 1 ]; then
      echo "  --force: the safety check failed, but discarding by force"
      do_rm "$subpath"
    else
      echo "✗ '$subpath' is not confirmed as clean Git residue (reason above). It may be data, so back it up/move it, then run again with --force." >&2
      exit 1
    fi
  fi
done < <(git submodule status)

# ── 5. Remove orphan gitdirs from .git/modules (those unrelated to the current submodule names) ───
echo "▶ orphan gitdir check"
if [ -d .git/modules ]; then
  for d in .git/modules/*/; do
    [ -d "$d" ] || continue
    nm="$(basename "$d")"
    if ! printf '%s\n' "$gm_names" | grep -qxF "$nm"; then
      echo "  remove orphan gitdir: $d"
      do_rm "${d%/}"
    fi
  done
fi

# ── 6. Init + checkout of the new nested structure ───────────────────────────────────────
echo "▶ submodule update --init --recursive"
do_git submodule update --init --recursive

# ── 7. Verification ───────────────────────────────────────────────────────────────
echo "▶ verify"
if [ "$DRY" = 1 ]; then
  echo "  (dry-run: no actual change — the DRY items above are the planned actions)"
  exit 0
fi
st="$(git submodule status --recursive)"
printf '%s\n' "$st"
if printf '%s\n' "$st" | grep -qE '^[-+U]'; then
  echo "✗ some submodules are not yet aligned (-/+/U flags). Check the output above." >&2
  exit 1
fi
echo "✓ all submodules synchronized"
