#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# select-suites.sh — the sole owner of "which suites does this change require".
# =============================================================================
# Both consumers call this script; neither reimplements it. CI calls it once per
# umbrella workflow and guards each suite step on its output;
# scripts/test/run-suites.sh calls it for a local or phase run.
#
# SELECTION PREDICATE, per enumerated suite against a resolved delta:
#   - the suite's own path is in the delta; or
#   - any `ci-subject` token matches a delta path — an exact path token by
#     identity, a directory token by prefix, a glob token through the Actions
#     dialect matcher below; or
#   - a shared library under tests/lib/** is in the delta (every consumer's
#     behaviour can change).
#
# EVENT HANDLING is explicit, not incidental. Under the push topology
# `origin/main` equals HEAD and the delta is empty BY CONSTRUCTION — proved
# hermetically by tests/test-push-context-base-ref.sh. A purely delta-driven
# selector would select nothing on a push and silently lose all coverage. So a
# `push` event, or an empty delta from a resolved base, selects the FULL SET.
# Narrowing happens only where a non-empty delta was resolved.
#
# REPORTING is positive on both sides — one `SELECTED:` or `NOT-SELECTED:
# <path> <reason>` record per enumerated suite, on stderr. A verification check
# can then distinguish "correctly narrowed" from "the selector produced nothing
# at all", which a list of winners alone cannot.
#
# The base ref comes from `resolve_base_ref` in tests/lib/base-ref.sh, the
# registry's designated single definition site, and inherits its fail-loud
# contract: an unresolvable base is a visible BLOCK and a non-zero exit, never a
# silent empty selection.
#
# WORKTREE INCLUSION is opt-in through `--include-worktree`, off by default.
# With it on, the resolved delta is the UNION of the committed delta with the
# uncommitted one — `git diff --name-only HEAD` (tracked, staged and unstaged)
# plus `git ls-files --others --exclude-standard` (untracked, ignore rules
# honoured). The flag can only widen: the full-set rule keeps keying on the
# committed delta, so an empty committed delta still selects the full set; an
# unresolvable base is still a BLOCK, since the union applies only to a delta
# that resolved; and under a push event no delta is resolved at all, so the flag
# is inert there. Callers verifying a working tree (the interim capture point in
# scripts/test/suite-coverage.sh) pass it; CI, whose checkout is clean, does not.
#
# Usage:
#   bash scripts/test/select-suites.sh [--root <dir>] [--base <ref>]
#                                      [--event pull_request|push]
#                                      [--include-worktree]
#
# stdout: one selected repo-relative suite path per line.
# stderr: the per-subject SELECTED: / NOT-SELECTED: report.
# Exit:   0 normal, 1 BLOCK (unresolvable base, or an absent / empty
#         `ci-subject` header on an enumerated suite — validated ahead of the
#         selection loop, so a BLOCK never leaves a partial report behind),
#         2 usage.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=scripts/test/suite-manifest.sh
. "$SCRIPT_DIR/suite-manifest.sh"

ROOT=""
BASE=""
EVENT="${GITHUB_EVENT_NAME:-pull_request}"
INCLUDE_WORKTREE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --include-worktree) INCLUDE_WORKTREE=1 ;;
    --root)      require_value select-suites "$1" $# "${2:-}" || exit 2; ROOT="$2"; shift ;;
    --base)      require_value select-suites "$1" $# "${2:-}" || exit 2; BASE="$2"; shift ;;
    --event)     require_value select-suites "$1" $# "${2:-}" || exit 2; EVENT="$2"; shift ;;
    *)           echo "select-suites: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done
ROOT="${ROOT:-$DEFAULT_ROOT}"

# `glob_matches` — the Actions `paths:` dialect — is NOT defined here. It lives
# in scripts/test/suite-manifest.sh, sourced above: the dialect is how a
# `# ci-subject:` token is interpreted, and that grammar's definition site is
# that file. The two call sites below reach it unchanged through the source line
# this script already carries.

# ---------------------------------------------------------------------------
# resolve_delta <root> <base> <include-worktree> — repo-relative changed paths,
# one per line. Prints nothing and returns 1 when no base is resolvable
# (fail-loud) — base resolution comes first, so the uncommitted delta is never
# consulted as a substitute base. With <include-worktree> on, the committed
# delta is unioned with the uncommitted one; the union only adds paths.
# ---------------------------------------------------------------------------
resolve_delta() {
  local root="$1" base="$2" include_worktree="${3:-0}" resolved
  # shellcheck source=tests/lib/base-ref.sh
  if [ -f "$root/tests/lib/base-ref.sh" ]; then
    . "$root/tests/lib/base-ref.sh"
  elif [ -f "$DEFAULT_ROOT/tests/lib/base-ref.sh" ]; then
    . "$DEFAULT_ROOT/tests/lib/base-ref.sh"
  else
    return 1
  fi
  resolved="$(cd "$root" && resolve_base_ref "$base" 2>/dev/null)" || return 1
  [ -n "$resolved" ] || return 1
  local committed
  committed="$(cd "$root" && git diff --name-only "$resolved"...HEAD 2>/dev/null)"
  # An empty committed delta stays empty: the full-set rule in select_over keys
  # on it, and widening it here would turn "the full set runs" into a narrowed
  # selection — the one direction this flag must never take.
  if [ "$include_worktree" != 1 ] || [ -z "$committed" ]; then
    printf '%s\n' "$committed"
    return 0
  fi
  { printf '%s\n' "$committed"
    cd "$root" || return 1
    git diff --name-only HEAD 2>/dev/null
    git ls-files --others --exclude-standard 2>/dev/null
  } | grep -v '^$' | sort -u
}

# ---------------------------------------------------------------------------
# select_over <root> <event> <base> <include-worktree>
# ---------------------------------------------------------------------------
select_over() {
  local root="$1" event="$2" base="$3" include_worktree="${4:-0}"
  local delta="" full_set=0 lib_touched=0 suite tok path matched reason
  local hdr toks
  local -a suites=()
  local -A ci_subject_hdr=()

  # Enumerated once and reused by both the validation and selection loops below
  # — the header validated per suite here is cached too, so together this
  # replaces two `suite_enumerate` tree walks and a second per-suite
  # `suite_header_field` read with one of each.
  while IFS= read -r suite; do
    [ -n "$suite" ] && suites+=("$suite")
  done < <(suite_enumerate "$root")

  # HEADER VALIDATION, ahead of the selection loop. The docstring has always
  # stated a malformed header as a BLOCK; the detection did not exist, so a
  # suite with no `ci-subject:` line simply matched no token and reported
  # NOT-SELECTED with the ordinary no-match reason. Validating before anything
  # is selected is deliberate: a BLOCK discovered mid-report would leave a
  # partial report behind, which the reconciler now reads as evidence.
  # The validated header is cached per suite so the selection loop below reuses
  # it instead of re-reading and re-parsing each suite file a second time.
  for suite in ${suites[@]+"${suites[@]}"}; do
    if ! hdr="$(suite_header_field "$root/$suite" ci-subject)" || [ -z "$hdr" ]; then
      echo "BLOCK: select-suites — $suite declares no usable '# ci-subject:' header; refusing to select against an unreadable trigger surface" >&2
      echo "  A suite whose declared subject cannot be read is not correctly narrowed to nothing — it is unjudgeable." >&2
      return 1
    fi
    ci_subject_hdr["$suite"]="$hdr"
  done

  if [ "$event" = "push" ]; then
    full_set=1
    reason="push event — the full set runs (the push delta is empty by construction)"
  else
    if ! delta="$(resolve_delta "$root" "$base" "$include_worktree")"; then
      echo "BLOCK: select-suites — no base ref resolvable; refusing to emit an empty selection" >&2
      echo "  A base-dependent selection whose base does not resolve must fail loud, never narrow to nothing." >&2
      return 1
    fi
    if [ -z "$delta" ]; then
      full_set=1
      reason="empty delta from a resolved base — the full set runs"
    fi
  fi

  if [ "$full_set" -eq 0 ]; then
    while IFS= read -r path; do
      case "$path" in tests/lib/*) lib_touched=1 ;; esac
    done <<< "$delta"
  fi

  for suite in ${suites[@]+"${suites[@]}"}; do
    if [ "$full_set" -eq 1 ]; then
      printf 'SELECTED: %s\n' "$suite" >&2
      printf '%s\n' "$suite"
      continue
    fi
    matched=""
    while IFS= read -r path; do
      [ -n "$path" ] || continue
      if [ "$path" = "$suite" ]; then matched="own path $path in the delta"; break; fi
    done <<< "$delta"
    if [ -z "$matched" ] && [ "$lib_touched" -eq 1 ]; then
      matched="a shared library under tests/lib/** is in the delta"
    fi
    if [ -z "$matched" ]; then
      # `read -r -a` performs the IFS word split the loop wants and NO pathname
      # expansion. An unquoted `$( … )` split also glob-expands, so a wildcard
      # token was replaced by whatever the PROCESS'S WORKING DIRECTORY happened
      # to contain and never reached glob_matches as a pattern — selection
      # depended on where the selector was invoked from.
      read -r -a toks <<< "${ci_subject_hdr[$suite]:-}"
      for tok in ${toks[@]+"${toks[@]}"}; do
        while IFS= read -r path; do
          [ -n "$path" ] || continue
          if [ "$path" = "$tok" ] || glob_matches "$tok" "$path"; then
            matched="ci-subject token $tok matches $path"; break
          fi
        done <<< "$delta"
        [ -n "$matched" ] && break
      done
    fi
    if [ -n "$matched" ]; then
      printf 'SELECTED: %s %s\n' "$suite" "$matched" >&2
      printf '%s\n' "$suite"
    else
      printf 'NOT-SELECTED: %s no delta path matches its own path or any ci-subject token\n' "$suite" >&2
    fi
  done
  return 0
}

select_over "$ROOT" "$EVENT" "$BASE" "$INCLUDE_WORKTREE"
exit $?
