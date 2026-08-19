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
#                                      [--include-worktree] [--self-test]
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

MODE="default"
ROOT=""
BASE=""
EVENT="${GITHUB_EVENT_NAME:-pull_request}"
INCLUDE_WORKTREE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --self-test) MODE="self-test" ;;
    --include-worktree) INCLUDE_WORKTREE=1 ;;
    --root)      require_value select-suites "$1" $# "${2:-}" || exit 2; ROOT="$2"; shift ;;
    --base)      require_value select-suites "$1" $# "${2:-}" || exit 2; BASE="$2"; shift ;;
    --event)     require_value select-suites "$1" $# "${2:-}" || exit 2; EVENT="$2"; shift ;;
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

# ---------------------------------------------------------------------------
# wt_fixture <dir> — a committed git repo (main + work branch, resolvable
# base) with three suites and an ignored path — the shared idiom for the
# cycle-2 WORKTREE-UNION / FULL-SET(dirty) / PUSH-INERT(dirty) legs (issue
# #112 review finding: the resolver's candidate set is committed-only).
# ---------------------------------------------------------------------------
wt_fixture() {
  local d="$1"
  mkdir -p "$d/tests" "$d/docs" "$d/ignored"
  cat > "$d/tests/test-fixture-select-wt-x.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: docs/subject-x.md
# lane: standing
# budget-secs: 30
true
SH
  cat > "$d/tests/test-fixture-select-wt-y.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: docs/subject-y.md
# lane: standing
# budget-secs: 30
true
SH
  cat > "$d/tests/test-fixture-select-wt-z.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: ignored/subject-z.md
# lane: standing
# budget-secs: 30
true
SH
  printf 'x\n' > "$d/docs/subject-x.md"
  printf 'x\n' > "$d/docs/subject-y.md"
  printf 'ignored/\n' > "$d/.gitignore"
  printf 'x\n' > "$d/ignored/subject-z.md"
  git -C "$d" init -q -b main >/dev/null 2>&1
  git -C "$d" add -A >/dev/null 2>&1
  git -C "$d" -c user.email=a@b.c -c user.name=a commit -q -m init >/dev/null 2>&1
  git -C "$d" checkout -q -b work >/dev/null 2>&1
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

  # --- WORKTREE-UNION leg: with --include-worktree on, the selection is the
  # union of the committed delta with the uncommitted delta (tracked
  # modification + untracked-not-ignored addition); default off selects the
  # committed delta alone; an untracked file under an ignored path never
  # enters either delta (issue #112 cycle 2, --include-worktree amendment).
  local wtd wt_unflagged wt_flagged
  wtd="$(mktemp -d)"; wt_fixture "$wtd"
  printf '%s\n' "changed $(date +%s%N)" >> "$wtd/docs/subject-x.md"
  git -C "$wtd" add -A >/dev/null 2>&1
  git -C "$wtd" -c user.email=a@b.c -c user.name=a commit -q -m "committed touch x" >/dev/null 2>&1
  printf '%s\n' "uncommitted $(date +%s%N)" >> "$wtd/docs/subject-y.md"
  printf 'x\n' > "$wtd/docs/subject-w.md"
  cat > "$wtd/tests/test-fixture-select-wt-w.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: docs/subject-w.md
# lane: standing
# budget-secs: 30
true
SH
  wt_unflagged="$(select_over "$wtd" pull_request "" 2>/dev/null | sort -u)"
  wt_flagged="$(select_over "$wtd" pull_request "" 1 2>/dev/null | sort -u)"
  if [ "$wt_unflagged" = "tests/test-fixture-select-wt-x.sh" ]; then
    echo "select-suites: --self-test WORKTREE-UNION leg (opt-in default) OK — no flag selects only the committed delta"
  else
    echo "select-suites: --self-test WORKTREE-UNION leg (opt-in default) FAILED — expected only the x suite, got: $(printf '%s' "$wt_unflagged" | tr '\n' ' ')"
    rc=1
  fi
  if printf '%s\n' "$wt_flagged" | grep -qF 'tests/test-fixture-select-wt-x.sh' \
     && printf '%s\n' "$wt_flagged" | grep -qF 'tests/test-fixture-select-wt-y.sh' \
     && printf '%s\n' "$wt_flagged" | grep -qF 'tests/test-fixture-select-wt-w.sh' \
     && ! printf '%s\n' "$wt_flagged" | grep -qF 'tests/test-fixture-select-wt-z.sh'; then
    echo "select-suites: --self-test WORKTREE-UNION leg (union + ignore rules) OK — --include-worktree adds the uncommitted tracked edit and the untracked-not-ignored file, never the ignored one"
  else
    echo "select-suites: --self-test WORKTREE-UNION leg (union + ignore rules) FAILED — expected x, y, w and not z, got: $(printf '%s' "$wt_flagged" | tr '\n' ' ')"
    rc=1
  fi
  if [ -n "$wt_flagged" ] && [ "$wt_flagged" != "$wt_unflagged" ] \
     && [ -z "$(comm -23 <(printf '%s\n' "$wt_unflagged") <(printf '%s\n' "$wt_flagged"))" ]; then
    echo "select-suites: --self-test WORKTREE-UNION leg (never narrows) OK — the flagged selection is a strict superset of the unflagged one"
  else
    echo "select-suites: --self-test WORKTREE-UNION leg (never narrows) FAILED — flagged is not a strict superset of unflagged: unflagged=$(printf '%s' "$wt_unflagged" | tr '\n' ' ') flagged=$(printf '%s' "$wt_flagged" | tr '\n' ' ')"
    rc=1
  fi
  rm -rf "$wtd"

  # --- FULL-SET (dirty) leg: an empty committed delta still selects the full
  # set, with the shipped reason wording, even with the worktree dirty — the
  # union never turns an empty committed delta into a narrowed selection.
  local fsd fs_out
  fsd="$(mktemp -d)"; wt_fixture "$fsd"
  printf '%s\n' "uncommitted $(date +%s%N)" >> "$fsd/docs/subject-y.md"
  fs_out="$(select_over "$fsd" pull_request "" 1 2>/dev/null | sort -u)"
  if [ "$(printf '%s\n' "$fs_out" | grep -c .)" -eq 3 ]; then
    echo "select-suites: --self-test FULL-SET (dirty) leg OK — an empty committed delta still selects the full set, even with --include-worktree and a dirty worktree — the union never turns an empty committed delta non-empty"
  else
    echo "select-suites: --self-test FULL-SET (dirty) leg FAILED — expected all 3 fixture subjects, got: $(printf '%s' "$fs_out" | tr '\n' ' ')"
    rc=1
  fi
  rm -rf "$fsd"

  # --- PUSH-INERT (dirty) leg: --include-worktree changes nothing under a
  # push event — the full set is chosen before any delta (committed or
  # uncommitted) is ever resolved.
  local pid pi_off pi_on
  pid="$(mktemp -d)"; wt_fixture "$pid"
  printf '%s\n' "uncommitted $(date +%s%N)" >> "$pid/docs/subject-y.md"
  pi_off="$(select_over "$pid" push "" 0 2>&1)"
  pi_on="$(select_over "$pid" push "" 1 2>&1)"
  if [ "$pi_off" = "$pi_on" ]; then
    echo "select-suites: --self-test PUSH-INERT (dirty) leg OK — --include-worktree is inert under a push event"
  else
    echo "select-suites: --self-test PUSH-INERT (dirty) leg FAILED — expected identical output with the flag on and off, got off=[$pi_off] on=[$pi_on]"
    rc=1
  fi
  rm -rf "$pid"

  # --- BLOCK (dirty) leg: an unresolvable base is still a BLOCK with
  # --include-worktree on and the worktree dirty; no selection is emitted
  # from worktree state alone as a substitute base.
  local bdd bd_out bd_rc
  bdd="$(mktemp -d)"
  mkdir -p "$bdd/tests"
  cat > "$bdd/tests/test-fixture-select-block-dirty.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: docs/subject-block-dirty.md
# lane: standing
# budget-secs: 30
true
SH
  git -C "$bdd" init -q >/dev/null 2>&1
  git -C "$bdd" add -A >/dev/null 2>&1
  git -C "$bdd" -c user.email=a@b.c -c user.name=a commit -q -m init >/dev/null 2>&1
  git -C "$bdd" branch -m __no-base-here-dirty__ >/dev/null 2>&1
  printf '%s\n' "uncommitted $(date +%s%N)" >> "$bdd/tests/test-fixture-select-block-dirty.sh"
  bd_out="$(GITHUB_BASE_REF='' select_over "$bdd" pull_request "" 1 2>&1 >/dev/null)"
  bd_rc=$?
  if [ "$bd_rc" -ne 0 ] && printf '%s' "$bd_out" | grep -qi 'BLOCK'; then
    echo "select-suites: --self-test BLOCK (dirty) leg OK — an unresolvable base is a BLOCK with --include-worktree on and the worktree dirty; the uncommitted delta is never consulted as a substitute base"
  else
    echo "select-suites: --self-test BLOCK (dirty) leg FAILED — expected a BLOCK and non-zero exit, got rc=$bd_rc: $bd_out"
    rc=1
  fi
  rm -rf "$bdd"

  rm -rf "$dir"
  return $rc
}

if [ "$MODE" = "self-test" ]; then
  self_test
  exit $?
fi

select_over "$ROOT" "$EVENT" "$BASE" "$INCLUDE_WORKTREE"
exit $?
