#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# suite-coverage.sh — which suites must execute at this capture point, and which
# may be inherited from the cycle's green-tree register.
# =============================================================================
# It owns NO selection predicate of its own. Every reach question is answered by
# invoking scripts/test/select-suites.sh, so the inheritance boundary IS the
# selection boundary by construction rather than by agreement between two
# implementations. Governing record:
# docs/adr/0019-scope-fit-verification-policy.md.
#
# Usage:
#   bash scripts/test/suite-coverage.sh --ledger <path> --cycle <C>
#                                       [--root <dir>] [--candidates selection|all]
#   bash scripts/test/suite-coverage.sh --self-test
#
#   --candidates selection (default) — the candidate set is select-suites.sh over
#     the cycle base (this script's default base: the merge base with the
#     integration branch). The interim-step mode.
#   --candidates all — the candidate set is the whole enumerated set, so every
#     suite is reach-tested. The mode VALIDATE's evaluator and a gate evaluator
#     use.
#
# stdout: one repo-relative suite path per line — the set to execute, and
#         NOTHING else. Undecorated, because run-suites.sh --selected consumes it
#         as a path list; a record line here becomes a bogus suite path there.
# stderr: ONE record per ENUMERATED suite, in every candidate mode — a total
#         partition of suite_enumerate, never a report scoped to the candidate
#         set. This is the positive-reporting contract select-suites.sh
#         established: a reader must be able to tell "correctly narrowed" from
#         "the resolver produced nothing at all", which a list of winners cannot
#         express. The partition is also what makes the green-tree-use entry's
#         `inherited-suites` / `ran-suites` fields decidable.
#
#           RUN: <suite> <reason>
#           INHERIT: <suite> source: <heading> | head: <hash> | result: <line>
#           INHERIT: <suite> not-in-cycle-delta
#
# Exit:   0 normal, 1 BLOCK, 2 usage.
#
# A BLOCK NEVER EMITS A PARTIAL PLAN. stdout becomes the whole ENUMERATED set
# (which needs no selection call and therefore survives a selector BLOCK), every
# record is `RUN: <suite> block-fallback`, and the exit is non-zero. The fallback
# is the enumerated set and not the candidate set precisely because the candidate
# set may be the thing that failed to compute. A failure to reason about
# inheritance degrades to EXECUTING, never to skipping — and the phase-step idiom
# checks this exit status before the plan is consumed, so it cannot degrade to
# skipping by way of an unread status either:
#
#   bash scripts/test/suite-coverage.sh --ledger <ledger> --cycle <C> \
#     > .autoflow/issue-<N>-run-set.txt || { echo "suite-coverage BLOCK — running the enumerated set" >&2; }
#   bash scripts/test/run-suites.sh --selected .autoflow/issue-<N>-run-set.txt
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=scripts/test/suite-manifest.sh
. "$SCRIPT_DIR/suite-manifest.sh"

MODE="default"
ROOT=""
LEDGER=""
CYCLE=""
CANDIDATES="selection"
while [ $# -gt 0 ]; do
  case "$1" in
    --self-test)  MODE="self-test" ;;
    --root)       require_value suite-coverage "$1" $# "${2:-}" || exit 2; ROOT="$2"; shift ;;
    --ledger)     require_value suite-coverage "$1" $# "${2:-}" || exit 2; LEDGER="$2"; shift ;;
    --cycle)      require_value suite-coverage "$1" $# "${2:-}" || exit 2; CYCLE="$2"; shift ;;
    --candidates) require_value suite-coverage "$1" $# "${2:-}" || exit 2; CANDIDATES="$2"; shift ;;
    *)            echo "suite-coverage: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done
ROOT="${ROOT:-$DEFAULT_ROOT}"

# ---------------------------------------------------------------------------
# entry_result_is_pass <result line> — a `result` field states a pass.
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
# hash_shaped <value> — a ledger value admissible as a git rev.
#
# THIS IS THE END-OF-OPTIONS DISCIPLINE for ledger-derived refs, and it is
# stronger than `--` would be here. The ledger is a Markdown file an agent
# writes, so a `head` value is untrusted text, not a ref. `git merge-base
# --is-ancestor` takes no `--` separator at all, and select-suites.sh parses
# `--base <value>` with its own parser — so a positional separator could not
# protect either consumer. A shape gate that admits only [0-9a-f]{7,40} makes a
# leading `-` unrepresentable at the source, which covers every consumer
# downstream including the ones that have no separator to offer.
# ---------------------------------------------------------------------------
hash_shaped() {
  printf '%s' "$1" | grep -qE '^[0-9a-f]{7,40}$'
}

# ---------------------------------------------------------------------------
# resolve_over <root> <ledger> <cycle> <candidate mode>
#
# Emits the plan on fd 1 and the per-enumerated-suite records on fd 2.
# Returns 0 normally, 1 on BLOCK (after emitting the whole-enumerated fallback).
# ---------------------------------------------------------------------------
resolve_over() {
  local root="$1" ledger="$2" cycle="$3" mode="$4"
  local suite line heading key val
  local -a enumerated=() entry_headings=() entry_heads=() entry_trees=() entry_results=() entry_suites=()
  local -A decision=() record=() is_candidate=()

  while IFS= read -r suite; do
    [ -n "$suite" ] && enumerated+=("$suite")
  done < <(suite_enumerate "$root")

  block_fallback() { # <reason for the operator>
    local s
    echo "BLOCK: suite-coverage — $1" >&2
    echo "  Refusing to reason about inheritance; the whole enumerated set is the plan." >&2
    for s in ${enumerated[@]+"${enumerated[@]}"}; do
      printf 'RUN: %s block-fallback\n' "$s" >&2
      printf '%s\n' "$s"
    done
    return 1
  }

  # --- Capture point: one instant, foreground, from the repository root ----
  local dirty="" tree="" head=""
  dirty="$(cd "$root" && git status --porcelain 2>/dev/null)"
  tree="$(cd "$root" && git rev-parse "HEAD^{tree}" 2>/dev/null)"
  head="$(cd "$root" && git rev-parse HEAD 2>/dev/null)"

  # --- Candidate set ------------------------------------------------------
  # Under `all` this needs no selection call, which is what lets the BLOCK
  # fallback survive a selector that cannot compute.
  local sel_err sel_out sel_rc
  if [ "$mode" = all ]; then
    is_candidate=()
    for suite in ${enumerated[@]+"${enumerated[@]}"}; do is_candidate["$suite"]=1; done
  else
    sel_err="$(mktemp)"
    sel_out="$(bash "$SCRIPT_DIR/select-suites.sh" --root "$root" --event pull_request 2>"$sel_err")"
    sel_rc=$?
    if [ "$sel_rc" -ne 0 ]; then
      cat "$sel_err" >&2; rm -f "$sel_err"
      block_fallback "the candidate-set selection failed (select-suites exit $sel_rc)"
      return 1
    fi
    rm -f "$sel_err"
    while IFS= read -r suite; do
      [ -n "$suite" ] && is_candidate["$suite"]=1
    done <<< "$sel_out"
  fi

  # --- Ledger: this cycle's green-tree entries, in file order --------------
  # An entry whose field block is INCOMPLETE is not selected and yields a
  # mismatch — the shipped rule, which is exactly what retires a prior-grammar
  # (suites-less) entry without a legacy clause. An entry that is present but
  # MALFORMED — a required field carrying an empty or structurally invalid
  # value — is a BLOCK: unlike an absent field, it is a positive statement the
  # resolver cannot read, and guessing at it is how inheritance widens silently.
  if [ -n "$ledger" ] && [ -f "$ledger" ]; then
    local in_entry=0 e_tree="" e_head="" e_wt="" e_suites="" e_result="" e_auth="" e_heading=""
    flush_entry() {
      [ "$in_entry" -eq 1 ] || return 0
      in_entry=0
      # Incomplete field block -> not selected, silently. Not an error: it is
      # the mismatch the shipped rule already defines.
      [ -n "$e_tree" ] && [ -n "$e_head" ] && [ -n "$e_wt" ] && [ -n "$e_suites" ] \
        && [ -n "$e_result" ] && [ -n "$e_auth" ] || return 0
      if ! hash_shaped "$e_tree" || ! hash_shaped "$e_head" \
         || { [ "$e_wt" != clean ] && [ "$e_wt" != dirty ]; }; then
        MALFORMED_ENTRY="$e_heading"
        return 0
      fi
      entry_headings+=("$e_heading"); entry_trees+=("$e_tree"); entry_heads+=("$e_head")
      entry_results+=("$e_result"); entry_suites+=("$e_suites")
      return 0
    }
    MALFORMED_ENTRY=""
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        '### green-tree | cycle: '*)
          flush_entry
          heading="$line"
          val="${line#'### green-tree | cycle: '}"
          val="${val%%' |'*}"
          val="${val#"${val%%[![:space:]]*}"}"; val="${val%"${val##*[![:space:]]}"}"
          if [ "$val" = "$cycle" ]; then
            in_entry=1; e_heading="$heading"
            e_tree=""; e_head=""; e_wt=""; e_suites=""; e_result=""; e_auth=""
          fi
          ;;
        '#'*) flush_entry ;;
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
        *) flush_entry ;;
      esac
    done < "$ledger"
    flush_entry
    if [ -n "$MALFORMED_ENTRY" ]; then
      block_fallback "the ledger carries a malformed cycle-$cycle green-tree entry: $MALFORMED_ENTRY"
      return 1
    fi
  fi

  local n_entries=${#entry_headings[@]}

  # --- Fold: suite -> the entry index at which it last passed --------------
  # File order, later supersedes earlier. Without this fold a narrow run would
  # ERASE the coverage an earlier wide run established, and the register would
  # be no more useful than the whole-tree key it replaces.
  local -A cover_idx=()
  local i tok
  for (( i = 0; i < n_entries; i++ )); do
    entry_result_is_pass "${entry_results[$i]}" || continue
    for tok in ${entry_suites[$i]}; do
      cover_idx["$tok"]=$i
    done
  done

  # --- Whole-tree fast path: the shipped three conditions, verbatim -------
  # This is why the change cannot regress the whole-tree predicate's behaviour:
  # the new predicate's fast path IS the old predicate.
  local fast_idx=-1
  if [ -z "$dirty" ] && [ "$n_entries" -gt 0 ]; then
    local last=$(( n_entries - 1 ))
    if [ "${entry_trees[$last]}" = "$tree" ] && entry_result_is_pass "${entry_results[$last]}"; then
      fast_idx=$last
    fi
  fi

  # --- Reach test, memoised per distinct covering head --------------------
  local -A reach_run=() reach_done=()
  reach_answer() { # <head hash> <suite> -> echoes run|inherit|block
    local h="$1" s="$2" out rc err
    if [ "$h" = "$head" ]; then echo inherit; return 0; fi
    if ! (cd "$root" && git merge-base --is-ancestor "$h" HEAD >/dev/null 2>&1); then
      echo not-ancestor; return 0
    fi
    if [ -z "${reach_done[$h]:-}" ]; then
      err="$(mktemp)"
      out="$(bash "$SCRIPT_DIR/select-suites.sh" --root "$root" --base "$h" --event pull_request 2>"$err")"
      rc=$?
      if [ "$rc" -ne 0 ]; then cat "$err" >&2; rm -f "$err"; echo block; return 0; fi
      rm -f "$err"
      reach_run["$h"]=" $(printf '%s' "$out" | tr '\n' ' ') "
      reach_done["$h"]=1
    fi
    case "${reach_run[$h]}" in
      *" $s "*) echo run ;;
      *)        echo inherit ;;
    esac
  }

  local oot idx ans
  for suite in ${enumerated[@]+"${enumerated[@]}"}; do
    # Step 2 — a DECLARED out-of-tree reader executes before any other test and
    # regardless of the reach answer. It is a property of the suite, so the
    # declaration beats the derivation rather than qualifying it.
    oot="$(suite_header_field "$root/$suite" out-of-tree-inputs 2>/dev/null || true)"
    if [ "$oot" = yes ]; then
      decision["$suite"]=RUN; record["$suite"]="out-of-tree-inputs"; continue
    fi
    # Step 8 — a suite the cycle's own delta does not reach. A positive
    # statement that the resolver considered it and declined it, not a silence.
    if [ -z "${is_candidate[$suite]:-}" ]; then
      decision["$suite"]=INHERIT; record["$suite"]="not-in-cycle-delta"; continue
    fi
    # Step 3 — unchanged from the shipped predicate.
    if [ -n "$dirty" ]; then
      decision["$suite"]=RUN; record["$suite"]="dirty-worktree"; continue
    fi
    # Step 4 — whole-tree fast path.
    if [ "$fast_idx" -ge 0 ] && [[ " ${entry_suites[$fast_idx]} " == *" $suite "* ]]; then
      decision["$suite"]=INHERIT
      record["$suite"]="source: ${entry_headings[$fast_idx]} | head: ${entry_heads[$fast_idx]} | result: ${entry_results[$fast_idx]}"
      continue
    fi
    # Steps 5-7 — fold, head validation, reach test.
    idx="${cover_idx[$suite]:-}"
    if [ -z "$idx" ]; then
      decision["$suite"]=RUN
      if [ "$n_entries" -eq 0 ]; then record["$suite"]="no-entry"; else record["$suite"]="no-coverage"; fi
      continue
    fi
    local h="${entry_heads[$idx]}"
    if ! (cd "$root" && git rev-parse --verify -q "$h^{commit}" >/dev/null 2>&1); then
      decision["$suite"]=RUN; record["$suite"]="unresolvable-head"; continue
    fi
    ans="$(reach_answer "$h" "$suite")"
    case "$ans" in
      block)
        block_fallback "the reach test's selection failed against covering head $h"
        return 1
        ;;
      not-ancestor)
        # select-suites.sh resolves its delta with three-dot semantics, which
        # answers "changed since the merge base", not "differs from h". Where h
        # is not an ancestor those two questions diverge and the three-dot answer
        # can be NARROWER than the true content difference — so the resolver
        # refuses to reason and executes.
        decision["$suite"]=RUN; record["$suite"]="head-not-ancestor"
        ;;
      run)
        decision["$suite"]=RUN; record["$suite"]="reach-changed"
        ;;
      *)
        decision["$suite"]=INHERIT
        record["$suite"]="source: ${entry_headings[$idx]} | head: $h | result: ${entry_results[$idx]}"
        ;;
    esac
  done

  for suite in ${enumerated[@]+"${enumerated[@]}"}; do
    if [ "${decision[$suite]}" = RUN ]; then
      printf 'RUN: %s %s\n' "$suite" "${record[$suite]}" >&2
      printf '%s\n' "$suite"
    else
      printf 'INHERIT: %s %s\n' "$suite" "${record[$suite]}" >&2
    fi
  done
  return 0
}

# ---------------------------------------------------------------------------
# Self-test — hermetic fixture roots whose answer is known by construction.
#
# This is the ONLY layer that can distinguish a right reach derivation from a
# wrong one: a clean real tree cannot discriminate a working resolver from an
# inert one, which is the same ground select-suites.sh's own self-test stands on.
# It is therefore part of the declared surface, not a development convenience.
# ---------------------------------------------------------------------------
SELFTEST_RC=0
st_fail() { echo "suite-coverage: --self-test $1 FAILED — $2"; SELFTEST_RC=1; }
st_ok()   { echo "suite-coverage: --self-test $1 OK — $2"; }

# fixture_repo <dir> — a git repo with three suites, a shared library, and a
# `main` branch (the base resolve_base_ref falls back to).
fixture_repo() {
  local d="$1"
  mkdir -p "$d/tests/lib" "$d/docs" "$d/.autoflow"
  cat > "$d/tests/test-fx-cov-a.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: docs/subject-a.md
# lane: standing
# budget-secs: 5
true
SH
  cat > "$d/tests/test-fx-cov-b.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: docs/glob/**
# lane: standing
# budget-secs: 5
true
SH
  cat > "$d/tests/test-fx-cov-c.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: docs/subject-c.md
# lane: standing
# budget-secs: 5
true
SH
  printf '%s\n' 'x' > "$d/docs/subject-a.md"
  mkdir -p "$d/docs/glob"
  printf '%s\n' 'x' > "$d/docs/glob/g.md"
  printf '%s\n' 'x' > "$d/docs/subject-c.md"
  printf '%s\n' '# shared' > "$d/tests/lib/harness.sh"
  # The ledger lives under an ignored path, exactly as `.autoflow/` is ignored
  # in a real checkout. Without this the fixture ledger is itself an untracked
  # (or, once `git add -A` runs, a tracked) file, and every leg would answer
  # `dirty-worktree` — a fixture that cannot reach the branch it is testing.
  printf '%s\n' '.autoflow/' > "$d/.gitignore"
  git -C "$d" init -q -b main >/dev/null 2>&1
  git -C "$d" add -A >/dev/null 2>&1
  git -C "$d" -c user.email=a@b.c -c user.name=a commit -q -m base >/dev/null 2>&1
  # Work happens off `main`, because that is what resolve_base_ref falls back to
  # and a fixture sitting ON main has an empty delta BY CONSTRUCTION — which
  # select-suites.sh defines as "select everything". A fixture that cannot
  # produce a narrowed candidate set cannot test narrowing.
  git -C "$d" checkout -q -b work >/dev/null 2>&1
}

fx_commit() { # <dir> <path> <message>
  printf '%s\n' "changed $(date +%s%N)" >> "$1/$2"
  git -C "$1" add -A >/dev/null 2>&1
  git -C "$1" -c user.email=a@b.c -c user.name=a commit -q -m "$3" >/dev/null 2>&1
}

fx_entry() { # <ledger> <cycle> <tree> <head> <suites> [result]
  {
    printf '### green-tree | cycle: %s | runner: VERIFY step 1\n' "$2"
    printf -- '- tree: %s\n' "$3"
    printf -- '- head: %s\n' "$4"
    printf -- '- worktree: clean\n'
    printf -- '- suites: %s\n' "$5"
    printf -- '- result: %s\n' "${6:-run-suites: 3 passed, 0 failed, 0 timed out, of 3 executed}"
    printf -- '- authority: Green-tree register\n'
    printf '\n'
  } >> "$1"
}

# st_run <dir> <ledger> <cycle> <mode> — fills ST_PLAN / ST_REC / ST_RC.
st_run() {
  local err; err="$(mktemp)"
  ST_PLAN="$(bash "$SCRIPT_DIR/suite-coverage.sh" --root "$1" --ledger "$2" --cycle "$3" --candidates "$4" 2>"$err")"
  ST_RC=$?
  ST_REC="$(cat "$err")"
  rm -f "$err"
}

st_reason() { printf '%s\n' "$ST_REC" | grep -E "^(RUN|INHERIT): $1 " | head -1; }

self_test() {
  local d ledger tree head

  # --- SELECTION-SCOPED leg: a commit touching one subject narrows the plan
  # to the suites whose ci-subject closure reaches it, and every OTHER
  # enumerated suite is still recorded (the total-partition contract).
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  fx_commit "$d" docs/subject-a.md "touch a"
  st_run "$d" "$ledger" 1 selection
  if [ "$ST_PLAN" = "tests/test-fx-cov-a.sh" ]; then
    st_ok "SELECTION leg" "a one-subject delta plans only the suite whose ci-subject reaches it"
  else
    st_fail "SELECTION leg" "expected only test-fx-cov-a.sh, got: $(printf '%s' "$ST_PLAN" | tr '\n' ' ')"
  fi
  if [ "$(printf '%s\n' "$ST_REC" | grep -cE '^(RUN|INHERIT): ')" -eq 3 ] \
     && st_reason 'tests/test-fx-cov-b\.sh' | grep -qF 'not-in-cycle-delta'; then
    st_ok "PARTITION leg (selection)" "one record per enumerated suite; a non-candidate reads not-in-cycle-delta and carries no source"
  else
    st_fail "PARTITION leg (selection)" "expected 3 records with a sourceless not-in-cycle-delta, got: $ST_REC"
  fi
  rm -rf "$d"

  # --- PARTITION leg under --candidates all, with no ledger: every suite is
  # a candidate, none is covered, so the plan is the whole enumerated set and
  # the cause is no-entry rather than no-coverage.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  st_run "$d" "$ledger" 1 all
  if [ "$(printf '%s\n' "$ST_PLAN" | grep -c .)" -eq 3 ] \
     && [ "$(printf '%s\n' "$ST_REC" | grep -cE '^RUN: ')" -eq 3 ] \
     && st_reason 'tests/test-fx-cov-a\.sh' | grep -qF 'no-entry'; then
    st_ok "PARTITION leg (all)" "an empty register plans the whole enumerated set with cause no-entry"
  else
    st_fail "PARTITION leg (all)" "expected 3 RUN records with cause no-entry, got: $ST_REC"
  fi
  rm -rf "$d"

  # --- INCOMPLETE-ENTRY leg: an entry written under the prior grammar (no
  # `suites` field) is not selectable even with a matching tree, so the fast
  # path cannot fire on it and the whole candidate set executes.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"; head="$(git -C "$d" rev-parse HEAD)"
  {
    printf '### green-tree | cycle: 1 | runner: VERIFY step 1\n'
    printf -- '- tree: %s\n' "$tree"
    printf -- '- head: %s\n' "$head"
    printf -- '- worktree: clean\n'
    printf -- '- result: run-suites: 3 passed, 0 failed, 0 timed out, of 3 executed\n'
    printf -- '- authority: Green-tree register\n\n'
  } >> "$ledger"
  st_run "$d" "$ledger" 1 all
  if [ "$ST_RC" -eq 0 ] && [ "$(printf '%s\n' "$ST_PLAN" | grep -c .)" -eq 3 ] \
     && st_reason 'tests/test-fx-cov-a\.sh' | grep -qF 'no-entry'; then
    st_ok "INCOMPLETE-ENTRY leg" "a suites-less entry is not selected; the set executes with cause no-entry"
  else
    st_fail "INCOMPLETE-ENTRY leg" "expected the whole set to run with cause no-entry, got rc=$ST_RC: $ST_REC"
  fi
  rm -rf "$d"

  # --- FAST-PATH leg: the shipped whole-tree predicate, verbatim.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"; head="$(git -C "$d" rev-parse HEAD)"
  fx_entry "$ledger" 1 "$tree" "$head" "tests/test-fx-cov-a.sh tests/test-fx-cov-b.sh tests/test-fx-cov-c.sh"
  st_run "$d" "$ledger" 1 all
  if [ -z "$ST_PLAN" ] && [ "$(printf '%s\n' "$ST_REC" | grep -cE '^INHERIT: ')" -eq 3 ]; then
    st_ok "FAST-PATH leg" "an unmoved tree inherits every suite the entry covers — the shipped predicate as a special case"
  else
    st_fail "FAST-PATH leg" "expected an empty plan and 3 INHERIT records, got: $ST_REC"
  fi

  rm -rf "$d"

  # --- DECLARATION-BEATS-DERIVATION leg: the fast-path state again, with one
  # suite declaring the out-of-tree header — committed, so the capture point is
  # clean and the entry keys the tree that carries the declaration. It must RUN
  # where the fast path would otherwise have inherited it.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  awk '{print} /^# budget-secs:/ && !done {print "# out-of-tree-inputs: yes"; done=1}' \
    "$d/tests/test-fx-cov-c.sh" > "$d/tests/test-fx-cov-c.sh.new" \
    && mv "$d/tests/test-fx-cov-c.sh.new" "$d/tests/test-fx-cov-c.sh"
  git -C "$d" add -A >/dev/null 2>&1
  git -C "$d" -c user.email=a@b.c -c user.name=a commit -q -m declare >/dev/null 2>&1
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"; head="$(git -C "$d" rev-parse HEAD)"
  fx_entry "$ledger" 1 "$tree" "$head" "tests/test-fx-cov-a.sh tests/test-fx-cov-b.sh tests/test-fx-cov-c.sh"
  st_run "$d" "$ledger" 1 all
  if [ "$ST_PLAN" = "tests/test-fx-cov-c.sh" ] \
     && st_reason 'tests/test-fx-cov-c\.sh' | grep -qF 'out-of-tree-inputs'; then
    st_ok "DECLARATION leg" "a declared out-of-tree reader runs even under the whole-tree fast path"
  else
    st_fail "DECLARATION leg" "expected only test-fx-cov-c.sh with reason out-of-tree-inputs, got: $ST_REC"
  fi
  rm -rf "$d"

  # --- REACH-FIDELITY legs: the covering head is an ancestor and the reach
  # test decides. Three adversarial shapes, each of which must force RUN:
  # a path reached only by a glob token, the shared library, and the suite file.
  local target label
  for target in docs/glob/g.md tests/lib/harness.sh tests/test-fx-cov-b.sh; do
    d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
    head="$(git -C "$d" rev-parse HEAD)"
    fx_commit "$d" "$target" "move $target"
    fx_entry "$ledger" 1 "$(git -C "$d" rev-parse "$head^{tree}")" "$head" \
      "tests/test-fx-cov-a.sh tests/test-fx-cov-b.sh tests/test-fx-cov-c.sh"
    st_run "$d" "$ledger" 1 all
    label="REACH leg ($target)"
    if st_reason 'tests/test-fx-cov-b\.sh' | grep -qE '^RUN: .* reach-changed'; then
      st_ok "$label" "a moved reached path forces RUN with reason reach-changed"
    else
      st_fail "$label" "expected test-fx-cov-b.sh RUN reach-changed, got: $ST_REC"
    fi
    # The suite whose closure did not move still inherits — otherwise the leg
    # would pass equally under a resolver that runs everything.
    if [ "$target" != tests/lib/harness.sh ] \
       && ! st_reason 'tests/test-fx-cov-a\.sh' | grep -q '^INHERIT: '; then
      st_fail "$label" "expected test-fx-cov-a.sh to inherit, got: $ST_REC"
    fi
    rm -rf "$d"
  done

  # --- REFUSAL leg (a): covering head equals the captured head. An empty delta
  # is defined by select-suites.sh as SELECT EVERYTHING — the inverse of the
  # answer wanted here — so this special case is required, not incidental.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  head="$(git -C "$d" rev-parse HEAD)"
  fx_entry "$ledger" 1 "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" "$head" "tests/test-fx-cov-a.sh"
  st_run "$d" "$ledger" 1 all
  if st_reason 'tests/test-fx-cov-a\.sh' | grep -q '^INHERIT: '; then
    st_ok "REFUSAL leg (head == HEAD)" "the empty-delta full-set rule does not invert the reach answer"
  else
    st_fail "REFUSAL leg (head == HEAD)" "expected test-fx-cov-a.sh to inherit, got: $ST_REC"
  fi
  rm -rf "$d"

  # --- REFUSAL leg (b): covering head not an ancestor of HEAD. Three-dot delta
  # semantics answer a different question there, so the resolver executes.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  git -C "$d" checkout -q -b side >/dev/null 2>&1
  fx_commit "$d" docs/subject-a.md "side commit"
  local side; side="$(git -C "$d" rev-parse HEAD)"
  git -C "$d" checkout -q main >/dev/null 2>&1
  fx_commit "$d" docs/subject-c.md "main commit"
  fx_entry "$ledger" 1 "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" "$side" "tests/test-fx-cov-a.sh"
  st_run "$d" "$ledger" 1 all
  if st_reason 'tests/test-fx-cov-a\.sh' | grep -qE '^RUN: .* head-not-ancestor'; then
    st_ok "REFUSAL leg (not an ancestor)" "a covering head off the current history executes rather than being reasoned about"
  else
    st_fail "REFUSAL leg (not an ancestor)" "expected reason head-not-ancestor, got: $ST_REC"
  fi
  rm -rf "$d"

  # --- FOLD leg: a later NARROW entry must not erase the coverage an earlier
  # WIDE entry established. Without the fold, inheritance would not survive a
  # single further commit.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  local wide_head; wide_head="$(git -C "$d" rev-parse HEAD)"
  fx_entry "$ledger" 1 "$(git -C "$d" rev-parse "$wide_head^{tree}")" "$wide_head" \
    "tests/test-fx-cov-a.sh tests/test-fx-cov-b.sh tests/test-fx-cov-c.sh"
  fx_commit "$d" docs/subject-a.md "narrow work"
  local narrow_head; narrow_head="$(git -C "$d" rev-parse HEAD)"
  fx_entry "$ledger" 1 "$(git -C "$d" rev-parse "$narrow_head^{tree}")" "$narrow_head" \
    "tests/test-fx-cov-a.sh"
  fx_commit "$d" docs/subject-a.md "one more"
  st_run "$d" "$ledger" 1 all
  if st_reason 'tests/test-fx-cov-c\.sh' | grep -q '^INHERIT: ' \
     && st_reason 'tests/test-fx-cov-b\.sh' | grep -q '^INHERIT: '; then
    st_ok "FOLD leg" "a later narrow entry does not erase an earlier wide entry's coverage"
  else
    st_fail "FOLD leg" "expected b and c to inherit from the wide entry, got: $ST_REC"
  fi
  rm -rf "$d"

  # --- UNRESOLVABLE-HEAD leg: a well-formed but non-existent hash is never
  # handed to `merge-base --is-ancestor` (which answers "not an ancestor" and is
  # only accidentally safe) nor to `--base` (which silently answers a different
  # question). It is a named cause, and the fold moves on.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  fx_entry "$ledger" 1 "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" \
    "cafebabecafebabecafebabecafebabecafebabe" "tests/test-fx-cov-a.sh"
  st_run "$d" "$ledger" 1 all
  if st_reason 'tests/test-fx-cov-a\.sh' | grep -qE '^RUN: .* unresolvable-head'; then
    st_ok "UNRESOLVABLE-HEAD leg" "a ledger head that is not a resolvable commit is a named cause, not a mis-answer"
  else
    st_fail "UNRESOLVABLE-HEAD leg" "expected reason unresolvable-head, got: $ST_REC"
  fi
  rm -rf "$d"

  # --- BLOCK leg (a): a malformed entry field. stdout is the whole ENUMERATED
  # set, every record is block-fallback, and the exit is non-zero.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  fx_entry "$ledger" 1 "not-a-tree-hash" "$(git -C "$d" rev-parse HEAD)" "tests/test-fx-cov-a.sh"
  st_run "$d" "$ledger" 1 all
  if [ "$ST_RC" -ne 0 ] && [ "$(printf '%s\n' "$ST_PLAN" | grep -c .)" -eq 3 ] \
     && [ "$(printf '%s\n' "$ST_REC" | grep -cE '^RUN: .* block-fallback$')" -eq 3 ]; then
    st_ok "BLOCK leg (malformed entry)" "the whole enumerated set is the plan and the exit is non-zero"
  else
    st_fail "BLOCK leg (malformed entry)" "expected 3 block-fallback records and a non-zero exit, got rc=$ST_RC: $ST_REC"
  fi
  rm -rf "$d"

  # --- BLOCK leg (b): the BLOCK arises in the CANDIDATE-SET call itself — the
  # one case for which the fallback must be the enumerated set rather than the
  # candidate set. A suite with no ci-subject header is a select-suites BLOCK.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  cat > "$d/tests/test-fx-cov-noheader.sh" <<'SH'
#!/usr/bin/env bash
# lane: standing
# budget-secs: 5
true
SH
  git -C "$d" add -A >/dev/null 2>&1
  git -C "$d" -c user.email=a@b.c -c user.name=a commit -q -m noheader >/dev/null 2>&1
  st_run "$d" "$ledger" 1 selection
  if [ "$ST_RC" -ne 0 ] && [ "$(printf '%s\n' "$ST_PLAN" | grep -c .)" -eq 4 ] \
     && [ "$(printf '%s\n' "$ST_REC" | grep -cE '^RUN: .* block-fallback$')" -eq 4 ]; then
    st_ok "BLOCK leg (candidate-set selection)" "a selector BLOCK in the candidate call still yields the whole enumerated set"
  else
    st_fail "BLOCK leg (candidate-set selection)" "expected 4 block-fallback records and a non-zero exit, got rc=$ST_RC: $ST_REC"
  fi
  rm -rf "$d"

  return $SELFTEST_RC
}

if [ "$MODE" = "self-test" ]; then
  self_test
  exit $?
fi

if [ -z "$LEDGER" ] || [ -z "$CYCLE" ]; then
  echo "suite-coverage: --ledger <path> and --cycle <C> are required" >&2
  exit 2
fi
case "$CANDIDATES" in
  selection|all) ;;
  *) echo "suite-coverage: --candidates must be 'selection' or 'all', got: $CANDIDATES" >&2; exit 2 ;;
esac

resolve_over "$ROOT" "$LEDGER" "$CYCLE" "$CANDIDATES"
exit $?
