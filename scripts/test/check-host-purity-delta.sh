#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# scripts/test/check-host-purity-delta.sh
#
# Diff-scoped host-purity DELTA guard — Issue #788 ([#785-S2]).
#
# Fails when a service-identifier token (librechat, jeungpyeong, cbnu, portone,
# connev.io, …) is NEWLY introduced — present on an added ('+') line of the
# merge-base..HEAD diff, restricted to changed host tool/mechanism files. Tokens
# already present at the merge-base (context / removed lines) do NOT trip the
# guard; this is the DELTA, not a whole-tree scan.
#
# Config is data, not code:
#   --tokens  denylist  (default tests/fixtures/host-purity-tokens.txt): one ERE
#             per line, wrapped as a whole-token case-insensitive match.
#   --paths   scope+allowlist (default tests/fixtures/host-purity-paths.txt):
#             `include`/`exclude`/`allow` prefixed globs, precedence
#             allow > exclude > include (a total per-path rule).
#
# Diff source is injectable for hermetic testing:
#   --base <ref>  merge-base counterpart (default origin/main)
#   --head <ref>  diff tip           (default HEAD)
# BASE resolves as `git merge-base <head> <base>` with a `git rev-parse <base>`
# fallback (the boundary-suite idiom); an unresolvable base errors (exit 2).
# Operates on the git repo in $PWD.
#
# Exit contract:
#   0  clean
#   1  one-or-more leaks (all listed to stderr as
#      `LEAK: <file>:<lineno>: token '<t>'`)
#   2  usage / environment error (unknown flag, missing config, no resolvable base)
#
# Dependency-free: git + grep + bash only. Bash-3.2 portable.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

BASE_REF="origin/main"
HEAD_REF="HEAD"
TOKENS_FILE="$PROJECT_ROOT/tests/fixtures/host-purity-tokens.txt"
PATHS_FILE="$PROJECT_ROOT/tests/fixtures/host-purity-paths.txt"

usage() {
  cat >&2 <<'EOF'
usage: check-host-purity-delta.sh [--base <ref>] [--head <ref>]
                                  [--tokens <file>] [--paths <file>]
EOF
}

# ---------------------------------------------------------------------------
# Argument parsing (unknown flag / missing value -> exit 2)
# ---------------------------------------------------------------------------
while [ "$#" -gt 0 ]; do
  case "$1" in
    --base)   [ "$#" -ge 2 ] || { echo "error: --base needs a value" >&2; exit 2; }; BASE_REF="$2"; shift 2 ;;
    --head)   [ "$#" -ge 2 ] || { echo "error: --head needs a value" >&2; exit 2; }; HEAD_REF="$2"; shift 2 ;;
    --tokens) [ "$#" -ge 2 ] || { echo "error: --tokens needs a value" >&2; exit 2; }; TOKENS_FILE="$2"; shift 2 ;;
    --paths)  [ "$#" -ge 2 ] || { echo "error: --paths needs a value" >&2; exit 2; }; PATHS_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown argument '$1'" >&2; usage; exit 2 ;;
  esac
done

if [ ! -f "$TOKENS_FILE" ]; then
  echo "error: tokens file not found: $TOKENS_FILE" >&2; exit 2
fi
if [ ! -f "$PATHS_FILE" ]; then
  echo "error: paths file not found: $PATHS_FILE" >&2; exit 2
fi

# ---------------------------------------------------------------------------
# Load config
# ---------------------------------------------------------------------------
trim() {
  # trim leading/trailing whitespace
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

TOKENS=()
while IFS= read -r raw || [ -n "$raw" ]; do
  line="${raw%%$'\r'}"
  case "$line" in ''|'#'*) continue ;; esac
  line="$(trim "$line")"
  [ -n "$line" ] && TOKENS+=("$line")
done < "$TOKENS_FILE"

INCLUDE_GLOBS=()
EXCLUDE_GLOBS=()
ALLOW_GLOBS=()
while IFS= read -r raw || [ -n "$raw" ]; do
  line="${raw%%$'\r'}"
  case "$line" in ''|'#'*) continue ;; esac
  kw="${line%% *}"
  glob="${line#* }"
  glob="$(trim "$glob")"
  [ -n "$glob" ] || continue
  case "$kw" in
    include) INCLUDE_GLOBS+=("$glob") ;;
    exclude) EXCLUDE_GLOBS+=("$glob") ;;
    allow)   ALLOW_GLOBS+=("$glob") ;;
    *) : ;;  # unknown keyword ignored
  esac
done < "$PATHS_FILE"

if [ "${#TOKENS[@]}" -eq 0 ]; then
  echo "error: no tokens loaded from $TOKENS_FILE" >&2; exit 2
fi

# ---------------------------------------------------------------------------
# Glob -> anchored ERE. `**`=>.* ; `*`=>[^/]* ; `.`=>\. ; else literal.
# ---------------------------------------------------------------------------
glob_to_ere() {
  local g="$1" out="" i=0 n=${#1} c next
  while [ "$i" -lt "$n" ]; do
    c="${g:i:1}"
    if [ "$c" = "*" ]; then
      next="${g:i+1:1}"
      if [ "$next" = "*" ]; then
        out="$out.*"; i=$((i + 2)); continue
      else
        out="$out[^/]*"; i=$((i + 1)); continue
      fi
    elif [ "$c" = "." ]; then
      out="$out\\."
    elif [ "$c" = "/" ]; then
      out="$out/"
    else
      out="$out$c"
    fi
    i=$((i + 1))
  done
  printf '%s' "^$out\$"
}

glob_match() {
  # glob_match <path> <glob>
  local path="$1" ere
  ere="$(glob_to_ere "$2")"
  [[ "$path" =~ $ere ]]
}

# Precedence allow > exclude > include (total per-path rule).
in_scope() {
  local path="$1" g
  for g in "${ALLOW_GLOBS[@]:-}"; do
    [ -n "$g" ] && glob_match "$path" "$g" && return 1
  done
  for g in "${EXCLUDE_GLOBS[@]:-}"; do
    [ -n "$g" ] && glob_match "$path" "$g" && return 1
  done
  for g in "${INCLUDE_GLOBS[@]:-}"; do
    [ -n "$g" ] && glob_match "$path" "$g" && return 0
  done
  return 1
}

# ---------------------------------------------------------------------------
# Resolve BASE: merge-base(head, base) || rev-parse(base)
# ---------------------------------------------------------------------------
if ! git -C "$PWD" rev-parse --verify --quiet "$HEAD_REF^{commit}" >/dev/null 2>&1; then
  echo "error: cannot resolve head ref '$HEAD_REF'" >&2; exit 2
fi

BASE_SHA="$(git -C "$PWD" merge-base "$HEAD_REF" "$BASE_REF" 2>/dev/null || true)"
if [ -z "$BASE_SHA" ]; then
  BASE_SHA="$(git -C "$PWD" rev-parse --verify --quiet "$BASE_REF^{commit}" 2>/dev/null || true)"
fi
if [ -z "$BASE_SHA" ]; then
  echo "error: cannot resolve base ref '$BASE_REF' (no merge-base, no rev-parse)" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Token match — boundary-aware, portable whole-token (AC6/AC12).
# ---------------------------------------------------------------------------
line_leaks() {
  # emits matching tokens (one per line) for the given content
  local content="$1" tok pat
  for tok in "${TOKENS[@]}"; do
    pat="(^|[^[:alnum:]_])(${tok})([^[:alnum:]_]|$)"
    if printf '%s' "$content" | grep -qiE -- "$pat"; then
      printf '%s\n' "$tok"
    fi
  done
}

# ---------------------------------------------------------------------------
# Parse the unified diff (added-line only), --unified=0 --find-renames.
# ---------------------------------------------------------------------------
found=0
cur_file=""
scan=0
cur_lineno=0

while IFS= read -r line; do
  case "$line" in
    '+++ '*)
      path="${line#+++ }"
      case "$path" in
        b/*) path="${path#b/}" ;;
        /dev/null) path="" ;;
      esac
      cur_file="$path"
      if [ -n "$cur_file" ] && in_scope "$cur_file"; then scan=1; else scan=0; fi
      ;;
    '--- '*)
      : ;;  # old-file header, ignore
    '@@ '*)
      plus="${line#*+}"
      plus="${plus%% *}"
      cur_lineno="${plus%%,*}"
      ;;
    '+'*)
      # a genuine added line ('+++' already handled above)
      if [ "$scan" -eq 1 ] && [ -n "$cur_file" ]; then
        content="${line:1}"
        while IFS= read -r hit; do
          [ -n "$hit" ] || continue
          printf "LEAK: %s:%s: token '%s'\n" "$cur_file" "$cur_lineno" "$hit" >&2
          found=1
        done < <(line_leaks "${line:1}")
      fi
      cur_lineno=$((cur_lineno + 1))
      ;;
    '-'*)
      : ;;  # removed line ('---' already handled), no new-file lineno change
    ' '*)
      cur_lineno=$((cur_lineno + 1)) ;;  # context (absent under --unified=0)
    *)
      : ;;  # diff --git / index / rename / similarity headers — ignore
  esac
done < <(git -C "$PWD" diff --unified=0 --find-renames "$BASE_SHA".."$HEAD_REF")

if [ "$found" -ne 0 ]; then
  exit 1
fi
exit 0
