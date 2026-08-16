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
# Usage:
#   bash scripts/test/select-suites.sh [--root <dir>] [--base <ref>]
#                                      [--event pull_request|push] [--self-test]
#
# stdout: one selected repo-relative suite path per line.
# stderr: the per-subject SELECTED: / NOT-SELECTED: report.
# Exit:   0 normal, 1 BLOCK (unresolvable base, malformed header), 2 usage.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=scripts/test/suite-manifest.sh
. "$SCRIPT_DIR/suite-manifest.sh"

MODE="default"
ROOT=""
BASE=""
EVENT="${GITHUB_EVENT_NAME:-pull_request}"
while [ $# -gt 0 ]; do
  case "$1" in
    --self-test) MODE="self-test" ;;
    --root)      ROOT="${2:-}"; shift ;;
    --base)      BASE="${2:-}"; shift ;;
    --event)     EVENT="${2:-}"; shift ;;
    *)           echo "select-suites: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done
ROOT="${ROOT:-$DEFAULT_ROOT}"

# ---------------------------------------------------------------------------
# glob_matches <actions-dialect pattern> <path>
# The Actions `paths:` dialect, matched the way the conformance suite already
# implements it: `**` crosses `/`, a single `*` does not, and a token with no
# wildcard is an exact path or a directory prefix when it ends in `/`.
# ---------------------------------------------------------------------------
glob_matches() {
  local pattern="$1" path="$2" rx
  case "$pattern" in
    */) case "$path" in "$pattern"*) return 0 ;; esac; return 1 ;;
  esac
  case "$pattern" in
    *'*'*) ;;
    *) [ "$pattern" = "$path" ] && return 0; return 1 ;;
  esac
  # Translate the dialect into an ERE: `**` -> `.*`, `*` -> `[^/]*`.
  rx="$(printf '%s' "$pattern" \
    | sed -e 's/[.[\()+^$|]/\\&/g' -e 's/\*\*/\x01/g' -e 's/\*/[^\/]*/g' -e 's/\x01/.*/g')"
  printf '%s' "$path" | grep -qE "^${rx}$"
}

# ---------------------------------------------------------------------------
# resolve_delta <root> <base> — repo-relative changed paths, one per line.
# Prints nothing and returns 1 when no base is resolvable (fail-loud).
# ---------------------------------------------------------------------------
resolve_delta() {
  local root="$1" base="$2" resolved
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
  (cd "$root" && git diff --name-only "$resolved"...HEAD 2>/dev/null)
}

# ---------------------------------------------------------------------------
# select_over <root> <event> <base>
# ---------------------------------------------------------------------------
select_over() {
  local root="$1" event="$2" base="$3"
  local delta="" full_set=0 lib_touched=0 suite tok path matched reason

  if [ "$event" = "push" ]; then
    full_set=1
    reason="push event — the full set runs (the push delta is empty by construction)"
  else
    if ! delta="$(resolve_delta "$root" "$base")"; then
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

  while IFS= read -r suite; do
    [ -n "$suite" ] || continue
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
      for tok in $(suite_header_field "$root/$suite" ci-subject || true); do
        while IFS= read -r path; do
          [ -n "$path" ] || continue
          if [ "$path" = "$tok" ] || glob_matches "$tok" "$path"; then
            matched="ci-subject token $tok matches $path"; break
          fi
          case "$tok" in
            */) case "$path" in "$tok"*) matched="ci-subject directory token $tok covers $path"; break ;; esac ;;
          esac
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
  done < <(suite_enumerate "$root")
  return 0
}

# ---------------------------------------------------------------------------
# Self-test — hermetic fixture root whose answer is known by construction.
# A clean real tree cannot discriminate a working selector from an inert one.
# ---------------------------------------------------------------------------
self_test() {
  local dir rc=0 out report
  dir="$(mktemp -d)"
  mkdir -p "$dir/tests"
  cat > "$dir/tests/test-fixture-select-a.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: docs/subject-a.md
# lane: standing
# budget-secs: 30
true
SH
  cat > "$dir/tests/test-fixture-select-b.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: docs/subject-b.md
# lane: standing
# budget-secs: 30
true
SH

  # --- FULL-SET leg: a push event selects every enumerated subject ---------
  out="$(select_over "$dir" push "" 2>/dev/null)"
  if [ "$(printf '%s\n' "$out" | grep -c .)" -eq 2 ]; then
    echo "select-suites: --self-test FULL-SET leg OK — a push event selects the full enumerated set"
  else
    echo "select-suites: --self-test FULL-SET leg FAILED — expected 2 subjects, got: $(printf '%s' "$out" | tr '\n' ' ')"
    rc=1
  fi

  # --- REPORT leg: every enumerated subject carries exactly one record ------
  report="$(select_over "$dir" push "" 2>&1 >/dev/null)"
  if [ "$(printf '%s\n' "$report" | grep -cE '^(SELECTED|NOT-SELECTED): ')" -eq 2 ]; then
    echo "select-suites: --self-test REPORT leg OK — one positive record per enumerated subject"
  else
    echo "select-suites: --self-test REPORT leg FAILED — expected 2 records, got: $report"
    rc=1
  fi

  # --- BLOCK leg: an unresolvable base fails loud, never narrows to nothing.
  # The fixture repo is committed and then renamed off `main`, and has no
  # remote — so neither origin/main nor main resolves. Renaming is what makes
  # the state real: `git init` produces a `main` branch on any host whose
  # init.defaultBranch says so, and a fixture that keeps it is not the state
  # this leg claims to drive.
  local block_dir block_out block_rc
  block_dir="$(mktemp -d)"
  mkdir -p "$block_dir/tests"
  cat > "$block_dir/tests/test-fixture-select-block.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: docs/subject-block.md
# lane: standing
# budget-secs: 30
true
SH
  git -C "$block_dir" init -q >/dev/null 2>&1
  git -C "$block_dir" add -A >/dev/null 2>&1
  git -C "$block_dir" -c user.email=a@b.c -c user.name=a commit -q -m init >/dev/null 2>&1
  git -C "$block_dir" branch -m __no-base-here__ >/dev/null 2>&1
  block_out="$(GITHUB_BASE_REF='' select_over "$block_dir" pull_request "" 2>&1 >/dev/null)"
  block_rc=$?
  if [ "$block_rc" -ne 0 ] && printf '%s' "$block_out" | grep -qi 'BLOCK'; then
    echo "select-suites: --self-test BLOCK leg OK — an unresolvable base is a visible BLOCK and a non-zero exit"
  else
    echo "select-suites: --self-test BLOCK leg FAILED — expected a BLOCK and non-zero exit, got rc=$block_rc: $block_out"
    rc=1
  fi
  rm -rf "$block_dir"

  # --- MATCHER leg: the Actions dialect, both directions -------------------
  local row pattern path want got
  for row in \
    'docs/adr/**|||docs/adr/0016.md|||match' \
    'docs/adr/*|||docs/adr/sub/x.md|||nomatch' \
    'setup/manifest.json|||setup/manifest.json|||match' \
    'setup/manifest.json|||setup/manifest.json.bak|||nomatch' \
    'tests/|||tests/a/b.sh|||match'
  do
    pattern="${row%%'|||'*}"; path="${row#*'|||'}"; want="${path#*'|||'}"; path="${path%%'|||'*}"
    if glob_matches "$pattern" "$path"; then got=match; else got=nomatch; fi
    if [ "$got" != "$want" ]; then
      echo "select-suites: --self-test MATCHER leg FAILED — '$pattern' vs '$path': expected $want, got $got"
      rc=1
    fi
  done
  [ "$rc" -eq 0 ] && echo "select-suites: --self-test MATCHER leg OK — the Actions dialect matches and rejects as specified"

  rm -rf "$dir"
  return $rc
}

if [ "$MODE" = "self-test" ]; then
  self_test
  exit $?
fi

select_over "$ROOT" "$EVENT" "$BASE"
exit $?
