#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# green-tree-store.sh — sourced library: the repo-scoped SHARED Green-tree
# store, and the per-suite input-hash key its certificates are keyed by.
# =============================================================================
# SOURCED, NOT EXECUTED. It has no independent exit status and lives under
# scripts/ rather than tests/, so it is not an enumerated suite.
#
# THE SHARED STORE IS A CACHE, NOT A LEDGER. The per-issue decision ledger is an
# append-only record WITH AUTHORITY; this file is a content-addressed cache of
# past suite runs. Losing it, pruning it, or skipping an unreadable entry can
# only remove certificates, and a missing certificate resolves to RUN. Three
# rules follow, and they are the reason the dispositions here differ from the
# ledger's:
#
#   - it is not append-only in the ledger's sense — `green_tree_store_prune`
#     drops old entries by design;
#   - a malformed entry is SKIPPED WITH ONE WARNING, never a BLOCK. The ledger
#     BLOCKs on a malformed entry because a malformed LOCAL statement is a
#     positive claim this cycle cannot read, and guessing widens inheritance.
#     Skipping a foreign cache entry NARROWS, so degrading a local decision to a
#     whole-tree fallback over another issue's file would fail in the wrong
#     direction;
#   - it lives OUTSIDE the repository tree, under $AUTOFLOW_ARCHIVE_ROOT, so it
#     is never tracked content, never a dirty-worktree contributor at a capture
#     point, and never review surface.
#
# LOCATION
#   $AUTOFLOW_ARCHIVE_ROOT/<repo-key>/green-trees/register.md   (default $HOME/.autoflow)
#
# Both halves of that path are obtained by INVOKING scripts/cleanup/cleanup-issue.sh,
# never by re-typing it: `--print-repo-key` for <repo-key>, and
# `--check-archive-root` for the in-repo refusal. The archive root and the store
# root are ONE value with two consumers, so there is nothing for two
# implementations to agree about — a second copy could only disagree.
#
# The archive-root half is TAKEN FROM that guard rather than re-expanded beside
# it: `--check-archive-root` prints the absolute root it accepted, and the
# composition below uses that printed value. Re-expanding
# `${AUTOFLOW_ARCHIVE_ROOT}` here would resolve a relative value against
# WHICHEVER process interpolated it, while the guard validated it against
# `<root>` — one value with two anchors, agreeing only when `<root>` happens to
# be the caller's cwd (issue #130 cycle 2, review finding).
#
# THE CWD IS A TERM OF BOTH CALLS. `cleanup-issue.sh` resolves its root with a
# bare `git rev-parse --show-toplevel` and no `-C`, so it answers for the
# repository containing the CURRENT WORKING DIRECTORY. Every invocation below
# therefore runs in a subshell whose cwd is the caller's `<root>` — the same
# reason scripts/test/suite-coverage.sh resolves heads from `$root`: the
# caller's cwd is not necessarily the repository under test. Left unpinned, a
# fixture root would be keyed to THIS repository, and the symptom — a permanent
# cold start — is indistinguishable from correct fail-safe behaviour.
#
# ENTRY GRAMMAR (docs/autoflow-guide.md > VERIFY > Green-tree register)
#
#   ### green-tree-shared | issue: #<N> | cycle: <C> | runner: <PHASE> step <S>
#   - tree: <hash>
#   - head: <hash>
#   - worktree: clean
#   - suites: <repo-relative path>@<input-hash> [<repo-relative path>@<input-hash> ...]
#   - result: <summary line>
#   - authority: Green-tree register (shared store)
#
# The marker is `### green-tree-shared | `, deliberately NOT the ledger's
# `### green-tree | cycle: `: the ledger scanner's marker literal stays
# untouched so every shipped entry answers exactly as today, and `cycle`
# numbering is per-issue, so a shared file carrying the ledger marker would
# collide two issues' cycle 1 entries under one selection rule.
#
# Exit code 65 — the archive path's own refusal code — is propagated verbatim by
# `green_tree_store_path` when the store resolves inside the repository tree.
# =============================================================================

# Own directory, resolved from THIS file rather than from $SCRIPT_DIR: the
# sourcing script's $SCRIPT_DIR is its own, and both callers happen to sit in
# this directory today, which is exactly the kind of coincidence a library must
# not depend on.
GREEN_TREE_STORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GREEN_TREE_CLEANUP_WRAPPER="$GREEN_TREE_STORE_DIR/../cleanup/cleanup-issue.sh"

# `suite_header_field`, `suite_enumerate` and `glob_matches` come from the suite
# manifest library — the single definition site of the header grammar and of the
# Actions `paths:` dialect the closure below interprets. Sourced here only when a
# caller has not already brought it in.
if ! command -v suite_header_field >/dev/null 2>&1; then
  # shellcheck source=scripts/test/suite-manifest.sh
  . "$GREEN_TREE_STORE_DIR/suite-manifest.sh"
fi

# ---------------------------------------------------------------------------
# green_tree_store_path <root> — the shared register path for the repository at
# <root>. Prints the path and returns 0; prints nothing and returns 65 when the
# store root resolves inside the repository tree (the shipped guard's own code,
# because it is literally the shipped guard); returns 1 when the repository key
# cannot be derived.
#
# THE PRINTED PATH IS ABSOLUTE AND OPENABLE FROM ANY CWD, and its archive-root
# half is the root the guard accepted FOR <root> — so it is not re-interpretable
# by whichever process opens it next. It is absolute, NOT normalized: a relative
# $AUTOFLOW_ARCHIVE_ROOT yields literal `..` segments (`<root>/../ark/…`), which
# open correctly but do not compare byte-wise against the same directory spelled
# another way. Consumers that must decide whether two such paths name one
# directory compare them by OS resolution (`cd -P` + `pwd`), never by bytes.
# ---------------------------------------------------------------------------
green_tree_store_path() {
  local root="$1" key prefix rc
  prefix="$( cd "$root" 2>/dev/null && bash "$GREEN_TREE_CLEANUP_WRAPPER" --check-archive-root 2>/dev/null )"
  rc=$?
  [ "$rc" -eq 0 ] || return "$rc"
  key="$( cd "$root" 2>/dev/null && bash "$GREEN_TREE_CLEANUP_WRAPPER" --print-repo-key 2>/dev/null )"
  [ -n "$key" ] || return 1
  # An operator-supplied trailing slash would otherwise compose `<root>//<key>`.
  printf '%s/%s/green-trees/register.md' "${prefix%/}" "$key"
}

# ---------------------------------------------------------------------------
# green_tree_shared_scan <store file> — parse the shared store into one
# TAB-separated record per entry, in file order:
#
#   OK<TAB><heading><TAB><tree><TAB><head><TAB><suites><TAB><result>
#   BAD<TAB><heading>
#
# `BAD` is a malformed entry — a required field carrying a structurally invalid
# value. The caller warns once and skips it; see the cache/ledger distinction in
# the header. An INCOMPLETE field block is not malformed: it is silently
# unselectable, exactly as it is in the ledger, which is what retires a
# prior-grammar entry without a legacy clause.
#
# No field value may contain a TAB, and none does: the heading, the two hashes
# and the space-separated suites field are all machine-written, and `result` is
# a runner summary line.
# ---------------------------------------------------------------------------
green_tree_shared_scan() {
  local store="$1"
  [ -n "$store" ] && [ -f "$store" ] || return 0
  local line key val
  local in_entry=0 heading="" e_tree="" e_head="" e_wt="" e_suites="" e_result="" e_auth=""

  _gts_flush() {
    [ "$in_entry" -eq 1 ] || return 0
    in_entry=0
    [ -n "$e_tree" ] && [ -n "$e_head" ] && [ -n "$e_wt" ] && [ -n "$e_suites" ] \
      && [ -n "$e_result" ] && [ -n "$e_auth" ] || return 0
    if ! printf '%s' "$e_tree" | grep -qE '^[0-9a-f]{7,40}$' \
       || ! printf '%s' "$e_head" | grep -qE '^[0-9a-f]{7,40}$' \
       || [ "$e_wt" != clean ]; then
      printf 'BAD\t%s\n' "$heading"
      return 0
    fi
    printf 'OK\t%s\t%s\t%s\t%s\t%s\n' "$heading" "$e_tree" "$e_head" "$e_suites" "$e_result"
    return 0
  }

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '### green-tree-shared | '*)
        _gts_flush
        in_entry=1; heading="$line"
        e_tree=""; e_head=""; e_wt=""; e_suites=""; e_result=""; e_auth=""
        ;;
      '#'*) _gts_flush ;;
      '- '*)
        if [ "$in_entry" -eq 1 ]; then
          key="${line#- }"; val="${key#*: }"; key="${key%%:*}"
          case "$key" in
            tree)      e_tree="$val" ;;
            head)      e_head="$val" ;;
            worktree)  e_wt="$val" ;;
            suites)    e_suites="$val" ;;
            result)    e_result="$val" ;;
            authority) e_auth="$val" ;;
          esac
        fi
        ;;
      '') ;;
      *) _gts_flush ;;
    esac
  done < "$store"
  _gts_flush
}

# ---------------------------------------------------------------------------
# entry_result_is_pass <result line> — a `result` field states a pass.
#
# Defined HERE, in the library both readers of a register entry source, because
# the ledger and the shared store admit an entry on the same question and a
# second copy could only disagree about it.
# Conservative by construction: a line naming a non-zero failed or timed-out
# count is not a pass, and a line that names no passing outcome at all is not a
# pass either. An unrecognised line therefore falls to "not a pass", which
# degrades to executing.
# ---------------------------------------------------------------------------
entry_result_is_pass() {
  local line="$1"
  printf '%s' "$line" | grep -qE '[1-9][0-9]* (failed|timed out)' && return 1
  printf '%s' "$line" | grep -qiE '\bpass(ed)?\b' || return 1
  return 0
}

# ---------------------------------------------------------------------------
# green_tree_suite_token_path <token> / green_tree_suite_token_hash <token>
#
# A `suites` token is `<path>[@<input-hash>]`, split at the LAST `@`. A token
# with no `@` is the shipped bare-path form: it still folds and still satisfies
# the fast path's membership test, but it carries NO input-hash certificate, so
# the input-hash short-circuit cannot fire on it. Every entry already written
# therefore answers exactly as today — the extension is additive at the token
# level, not a grammar migration.
#
# Only the LEFT half is ever printed into a plan. The resolver's stdout is
# consumed directly as a path list by run-suites.sh --selected, so a token echoed
# in place of its path hands the runner a file that does not exist — a failure
# that is silent in the resolver and surfaces one layer downstream.
# ---------------------------------------------------------------------------
green_tree_suite_token_path() {
  case "$1" in
    *@*) printf '%s' "${1%@*}" ;;
    *)   printf '%s' "$1" ;;
  esac
}

green_tree_suite_token_hash() {
  case "$1" in
    *@*) printf '%s' "${1##*@}" ;;
    *)   printf '' ;;
  esac
}

# ---------------------------------------------------------------------------
# green_tree_tree_blobs <root> <tree> — "<blob-sha><TAB><repo-relative path>"
# for every tracked path at <tree>, read ONCE per (root, tree) and memoised, so
# the closure below is not one `git` call per suite per token.
# ---------------------------------------------------------------------------
declare -gA GREEN_TREE_BLOB_CACHE=()
green_tree_tree_blobs() {
  local root="$1" tree="$2" ck="$1|$2"
  if [ -z "${GREEN_TREE_BLOB_CACHE[$ck]+set}" ]; then
    GREEN_TREE_BLOB_CACHE[$ck]="$(
      cd "$root" 2>/dev/null && git ls-tree -r "$tree" 2>/dev/null \
        | awk -F'\t' '{ split($1, m, " "); if (m[2] == "blob") printf "%s\t%s\n", m[3], $2 }'
    )"
  fi
  printf '%s\n' "${GREEN_TREE_BLOB_CACHE[$ck]}"
}

# ---------------------------------------------------------------------------
# suite_input_hash <root> <tree> <suite> — the content key for ONE suite at ONE
# tree. Prints a twelve-character lower-hex hash and returns 0; prints nothing
# and returns 1 when the suite declares no usable `# ci-subject:` header.
#
# THE INPUT CLOSURE IS EXACTLY THE PATH SET THE SELECTION PREDICATE READS
# (scripts/test/select-suites.sh):
#
#   1. the suite's own repo-relative path;
#   2. every tracked path matching any token of the suite's `# ci-subject:`
#      header — exact token by identity, directory token by prefix, glob token
#      through `glob_matches`;
#   3. every tracked path under `tests/lib/`.
#
# ITEM 3 IS LOAD-BEARING and is the point most likely to be got wrong. The
# selector selects EVERY suite when any shared library changes, so a key that
# omitted `tests/lib/**` would be narrower than the selection boundary, and the
# "the inheritance boundary IS the selection boundary" contract would become
# FALSE rather than tightened.
#
# An absent or empty `ci-subject` header returns 1 — the disposition
# select-suites.sh already applies verbatim: a suite whose declared subject
# cannot be read is unjudgeable, not narrowed to nothing. The caller resolves a
# hash-less suite by running it.
#
# `git hash-object` is the digest rather than `shasum`/`sha256sum` because it is
# present wherever the rest of this path already runs and has no macOS/Linux flag
# divergence.
# ---------------------------------------------------------------------------
suite_input_hash() {
  local root="$1" tree="$2" suite="$3"
  local hdr tok sha path lit manifest
  hdr="$(suite_header_field "$root/$suite" ci-subject 2>/dev/null || true)"
  [ -n "$hdr" ] || return 1

  local -a toks=()
  read -r -a toks <<< "$hdr"

  manifest="$(
    while IFS=$'\t' read -r sha path; do
      [ -n "$path" ] || continue
      if [ "$path" = "$suite" ]; then printf '%s %s\n' "$sha" "$path"; continue; fi
      case "$path" in tests/lib/*) printf '%s %s\n' "$sha" "$path"; continue ;; esac
      for tok in ${toks[@]+"${toks[@]}"}; do
        [ -n "$tok" ] || continue
        if [ "$path" = "$tok" ]; then printf '%s %s\n' "$sha" "$path"; break; fi
        # A wildcard token is pre-filtered by its own literal prefix before
        # `glob_matches` is called. The translation the matcher performs is
        # anchored and begins with that literal, so the filter cannot exclude a
        # path the matcher would have accepted — it only keeps the dialect's
        # subprocess off the paths that cannot match.
        case "$tok" in
          *'*'*)
            lit="${tok%%\**}"
            case "$path" in "$lit"*) ;; *) continue ;; esac
            ;;
        esac
        if glob_matches "$tok" "$path"; then printf '%s %s\n' "$sha" "$path"; break; fi
      done
    done < <(green_tree_tree_blobs "$root" "$tree") | LC_ALL=C sort -k2,2
  )"

  printf '%s\n' "$manifest" | git hash-object -t blob --stdin 2>/dev/null | cut -c1-12
}

# ---------------------------------------------------------------------------
# green_tree_store_append <store path> <entry text> — append one entry as ONE
# write. The new content is composed into a temporary file BESIDE the register
# and moved into place, so a concurrent or interrupted append cannot leave a
# half-entry another cycle must interpret, and a completed append leaves no
# residue beside the register.
# ---------------------------------------------------------------------------
green_tree_store_append() {
  local store="$1" entry="$2" dir tmp
  dir="$(dirname "$store")"
  mkdir -p "$dir" || return 1
  tmp="$(mktemp "$dir/.register.XXXXXX")" || return 1
  { [ -f "$store" ] && cat "$store"; printf '%s' "$entry"; } > "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$store" || { rm -f "$tmp"; return 1; }
  return 0
}

# ---------------------------------------------------------------------------
# green_tree_store_prune <store path> <keep> — retain the <keep> most recent
# entries and drop the rest. The store is append-only in file order, so "most
# recent" is the tail. Unbounded growth is a cost every LATER issue pays, since
# every resolver call parses the whole file.
# ---------------------------------------------------------------------------
green_tree_store_prune() {
  local store="$1" keep="$2" total dir tmp
  [ -f "$store" ] || return 0
  case "$keep" in ''|*[!0-9]*) return 2 ;; esac
  total="$(grep -cF '### green-tree-shared | ' "$store" 2>/dev/null || true)"
  [ -n "$total" ] || total=0
  [ "$total" -gt "$keep" ] || return 0
  dir="$(dirname "$store")"
  tmp="$(mktemp "$dir/.register.XXXXXX")" || return 1
  awk -v drop="$(( total - keep ))" '
    index($0, "### green-tree-shared | ") == 1 { seen++ }
    seen > drop { print }
  ' "$store" > "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$store" || { rm -f "$tmp"; return 1; }
  return 0
}
