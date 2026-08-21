#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# scripts/cleanup/cleanup-issue.sh
#
# AutoFlow Post-Merge Cleanup helper — ARCHIVES (moves, never deletes) a
# resolved issue's `.autoflow/issue-<N>.*` + `.autoflow/issue-<N>-*` management
# files (state JSON, decision ledger, design docs, phase/eval reports) out of
# the repo tree into an external, repo-identity-keyed store
# `${AUTOFLOW_ARCHIVE_ROOT:-$HOME/.autoflow}/<repo-key>/issue-<N>-<date>/`. Run
# at PREFLIGHT prior-cycle resolution once the issue's PR is observed merged or
# closed (see docs/git-workflow.md > Post-Merge Cleanup). The live `.autoflow/`
# location, `.gitignore`, and the hook gate are untouched — only the resolved
# issue's file set migrates out at the cycle's mutation-freeze point.
#
# WHY A SCRIPT (not a bare `rm`): the cleanup is invoked by PATH
# (`scripts/cleanup/cleanup-issue.sh <N>`), so the Bash command carries no `rm`
# token. Claude Code permission precedence is deny > allow, so an `rm`
# allow-exception (e.g. `Bash(rm -f .autoflow/issue-*)`) CANNOT override a broad
# `rm` deny (e.g. `Bash(rm:*)`) — the deny always wins. A non-`rm` wrapper is
# never matched by an rm deny, so this lets a broad rm deny coexist with
# AutoFlow cleanup. Internally the terminal action is a scoped `mv` (no `rm` and
# no destruction at all), confined to `.autoflow/` (maxdepth 1).
#
# NUMBER-BOUNDARY MATCH: the issue's files are `issue-<N>.json` (state) and
# `issue-<N>-*` (companions) — i.e. the char after <N> is always `.` or `-`,
# never a digit. Matching `\( -name "issue-${N}.*" -o -name "issue-${N}-*" \)`
# (NOT a bare `issue-${N}*` glob) archives only issue <N> and never a
# prefix-collision sibling — `12` must not match `123`/`120` (review finding).
# The digits-only guard on N additionally blocks globs / path traversal / slashes.
#
# REPO-KEY: `--print-repo-key [<url>|--no-origin]` prints the derived archive
# key (`<org>__<repo>` from the origin URL, or a path-encoding fallback) and
# exits 0. It is a bounded introspection query, parsed ABOVE the `.autoflow/`
# existence gate so it answers whether or not that directory exists. It is NOT
# CWD-independent, and the distinction matters to every caller: the root comes
# from a bare `git rev-parse --show-toplevel` with no `-C`, so the subcommand
# answers for the repository containing the CURRENT WORKING DIRECTORY. A caller
# asking about some other repository must invoke it with its cwd inside that
# repository — the cwd is a term of the call, not an incidental.
#
# ARCHIVE-ROOT GATE: `--check-archive-root` runs the in-repo refusal below and
# exits 0 when the archive root resolves outside the repo tree, 65 when it does
# not. Same hoisting, same CWD contract. It exists so the Green-tree register's
# shared store — which lives under that same `$AUTOFLOW_ARCHIVE_ROOT` — reaches
# THIS guard rather than carrying a copy of it: one root with two consumers has
# nothing for two implementations to agree about, and a second copy could only
# disagree.
#
# Allow-list (so it never prompts even when rm is denied):
#   "Bash(./scripts/cleanup/cleanup-issue.sh:*)"   (or the no-`./` form you invoke)
#
# Usage:
#   scripts/cleanup/cleanup-issue.sh <issue-number> [<issue-number> ...]
#   scripts/cleanup/cleanup-issue.sh --print-repo-key [<url>|--no-origin]
#   scripts/cleanup/cleanup-issue.sh --check-archive-root
set -euo pipefail

# derive_repo_key <url> <root> — PURE normalization of an origin URL to a
# filesystem-safe archive key. $1 = origin URL ('' → path-encoding fallback over
# $2 = repo root, mirroring Claude Code's ~/.claude/projects/<key> scheme). The
# URL is an argument (not a live `git` call inside the function) so AC-2
# unit-tests the normalization table-driven and hermetic.
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

# physical_path <path> — canonicalize to the PHYSICAL absolute path, resolving
# symlinks portably (POSIX `cd -P` + `pwd`; macOS has no `realpath -m`
# guarantee). A relative path is absolutized against $PWD first (ledger E12);
# a not-yet-existing tail is re-appended after resolving the nearest existing
# directory ancestor, so a fresh archive root canonicalizes too.
physical_path() {
  p="$1"; tail=""
  case "$p" in
    /*) : ;;
    *)  p="$PWD/$p" ;;
  esac
  while [ ! -d "$p" ] && [ "$p" != "/" ]; do
    tail="/${p##*/}$tail"
    p="${p%/*}"
    [ -z "$p" ] && p="/"
  done
  p="$(cd -P "$p" 2>/dev/null && pwd)" || return 1
  [ "$p" = "/" ] && p=""
  printf '%s' "${p}${tail}"
}

# gate_archive_root <repo root> — the boundary guard (AC-3 hardening): refuse an
# archive root INSIDE the repo tree, since archiving into the tree would break
# repo-tree non-interference. The compare is over the PHYSICAL resolution of
# BOTH sides, not the textual prefix, so neither a relative value (GATE:PLAN
# finding, ledger E12) nor a symlink at an outside-tree path whose target
# resolves inside the tree (AUDIT r1, ledger E15) can bypass the refuse. Fail
# closed (exit 65) if resolution is impossible.
#
# ONE FUNCTION, TWO CALLERS, hoisted above the `.autoflow/` existence gate: the
# archival path below and the `--check-archive-root` query. It sets
# $ARCHIVE_ROOT as a side effect, which the archival path then uses as the
# destination prefix — the guarded value and the used value are the same
# variable by construction, not by agreement.
gate_archive_root() {
  ARCHIVE_ROOT="${AUTOFLOW_ARCHIVE_ROOT:-$HOME/.autoflow}"
  ROOT_PHYS="$(cd -P "$1" && pwd)"
  if ! ARCHIVE_ROOT_PHYS="$(physical_path "$ARCHIVE_ROOT")"; then
    echo "refuse: AUTOFLOW_ARCHIVE_ROOT ($ARCHIVE_ROOT) cannot be resolved" >&2
    exit 65
  fi
  case "${ARCHIVE_ROOT_PHYS%/}/" in
    "$ROOT_PHYS"/*)
      echo "refuse: AUTOFLOW_ARCHIVE_ROOT ($ARCHIVE_ROOT) is inside the repo tree" >&2
      exit 65
      ;;
  esac
}

# Introspection subcommands — hoisted ABOVE the existence gate and the digits
# loop (a leading `--` is never mistaken for an issue number). Both resolve
# their root from the CWD; see the ARCHIVE-ROOT GATE / REPO-KEY notes above.
if [ "${1:-}" = "--check-archive-root" ]; then
  ROOT="$(git rev-parse --show-toplevel)"
  gate_archive_root "$ROOT"
  exit 0
fi

if [ "${1:-}" = "--print-repo-key" ]; then
  ROOT="$(git rev-parse --show-toplevel)"
  case "${2:-}" in
    '')          url="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)" ;;  # live remote
    --no-origin) url="" ;;                                                             # force fallback
    *)           url="$2" ;;                                                           # literal URL
  esac
  printf '%s\n' "$(derive_repo_key "$url" "$ROOT")"
  exit 0
fi

if [ "$#" -eq 0 ]; then
  echo "usage: $0 <issue-number> [<issue-number> ...]" >&2
  exit 64
fi

ROOT="$(git rev-parse --show-toplevel)"
AUTOFLOW_DIR="$ROOT/.autoflow"

if [ ! -d "$AUTOFLOW_DIR" ]; then
  echo "no .autoflow/ directory at $ROOT — nothing to archive"
  exit 0
fi

# The SAME guard the `--check-archive-root` query runs — called, never
# re-typed. It sets $ARCHIVE_ROOT, used as the destination prefix below.
gate_archive_root "$ROOT"

KEY="$(derive_repo_key "$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)" "$ROOT")"
DATE="$(date +%F)"

status=0
for N in "$@"; do
  # Guard: issue number must be digits only — blocks globs, path traversal, slashes.
  case "$N" in
    '' | *[!0-9]*)
      echo "refuse: issue number must be digits only, got '$N'" >&2
      status=64
      continue
      ;;
  esac

  # Number-boundary match: `issue-<N>.*` (state json) OR `issue-<N>-*` (companions).
  # A bare `issue-<N>*` would also match `issue-<N>3` etc. — see review finding.
  matches="$(find "$AUTOFLOW_DIR" -maxdepth 1 -type f \( -name "issue-${N}.*" -o -name "issue-${N}-*" \) 2>/dev/null || true)"

  # Per-issue scratch FIXTURES live one level down, in `.autoflow/fixtures/`:
  # the gate hook's discovery glob is single-level (`"$AUTOFLOW_DIR"/*.json`),
  # so a non-state JSON parked at the top level fail-closed-blocks every
  # score-gated command until removed — issue #18 moved such fixtures into the
  # subdir to stay off that glob. They are the same issue's scratch and are
  # archived with it, under the same digits-only guard and the same
  # number-boundary match. The `fixtures/` prefix is preserved in the archive so
  # a fixture cannot overwrite a top-level file that happens to share its name.
  fixtures="$(find "$AUTOFLOW_DIR/fixtures" -maxdepth 1 -type f \( -name "issue-${N}.*" -o -name "issue-${N}-*" \) 2>/dev/null || true)"

  if [ -z "$matches" ] && [ -z "$fixtures" ]; then
    echo "issue #${N}: no .autoflow/issue-${N}.* or issue-${N}-* files — nothing to archive"
    continue
  fi
  count="$( { printf '%s\n' "$matches"; printf '%s\n' "$fixtures"; } | grep -c . )"

  # Non-destructive archive move: a `-2`, `-3`, … conflict suffix rather than
  # overwriting a prior same-day archive (issue re-opened + re-closed).
  base="$ARCHIVE_ROOT/$KEY/issue-${N}-${DATE}"
  dest="$base"; s=2
  while [ -e "$dest" ]; do dest="${base}-${s}"; s=$((s + 1)); done
  mkdir -p "$dest"

  # Portable per-file move (BSD/macOS + GNU/Linux CI); filenames never contain
  # newlines. `mv` = atomic within a filesystem, copy+unlink across filesystems;
  # byte content is preserved either way.
  # Each loop is guarded: with an empty list the `while` body's last command is
  # a false `[ -n "" ]`, so the pipeline exits 1 and `set -e` would abort the
  # run mid-issue. Reachable since the early-continue now only fires when BOTH
  # lists are empty — a fixtures-only issue leaves `$matches` empty.
  if [ -n "$matches" ]; then
    printf '%s\n' "$matches" | while IFS= read -r f; do
      [ -n "$f" ] && mv "$f" "$dest/"
    done
  fi
  if [ -n "$fixtures" ]; then
    mkdir -p "$dest/fixtures"
    printf '%s\n' "$fixtures" | while IFS= read -r f; do
      [ -n "$f" ] && mv "$f" "$dest/fixtures/"
    done
  fi
  echo "issue #${N}: archived ${count} file(s) → ${dest}"
done

exit "$status"
