#!/bin/sh
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# issue-dir.sh — the repository key and the issue directory under .autoflow/
# (issue #423)
# =============================================================================
# POSIX sh, SOURCED (never executed). An issue's cycle files — the state file,
# the ledger, the unit and gate reports, the cycle-layer store and the issue
# proposal record — live in ONE directory per repository and issue number:
#
#   .autoflow/<repo-key>-issue-<N>/
#
# so two repositories' issues of the same number never share a name in one
# .autoflow/, and a new session picks an issue's whole checkpoint up from one
# directory. The archive (scripts/cleanup/cleanup-issue.sh) keys its store by
# the same <repo-key>. The scripts that ship into a consuming target source this
# file, so it ships with them (setup/manifest.json copy row, dest scripts/lib/).
#
#   derive_repo_key <url> <root>
#       `<owner>__<name>` from an origin URL or an `owner/name` pair; with an
#       empty <url>, a path encoding of <root>
#   autoflow_repo_key <root>
#       the key of the repository at <root>, from its origin remote
#   autoflow_issue_dir <root> <N> [<repo-key>]
#       <root>/.autoflow/<repo-key>-issue-<N>; the key defaults to <root>'s own

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

autoflow_issue_dir() {
  if [ -n "${3:-}" ]; then
    printf '%s/.autoflow/%s-issue-%s' "$1" "$3" "$2"
  else
    printf '%s/.autoflow/%s-issue-%s' "$1" "$(autoflow_repo_key "$1")" "$2"
  fi
}
