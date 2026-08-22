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
#           INHERIT: <suite> source: <heading> | head: <hash> | result: <line> | via: <basis>
#           INHERIT: <suite> not-in-cycle-delta
#
# Reasons: the block below is the ONE normative home of the per-suite reason
#         vocabulary. Every other passage that carries these tokens — this
#         script's own record sites, the guide's resolution-order narrative, a
#         green-tree-use entry's `run-reasons` field — is derived from it and is
#         held to it by tests/test-suite-coverage-agreement.sh. Adding a reason
#         means adding it here first; a token declared here and written nowhere
#         in the body fails the same leg.
#
#   reason-tokens: begin
#     out-of-tree-inputs
#     dirty-worktree
#     no-entry
#     no-coverage
#     unresolvable-head
#     head-not-ancestor
#     reach-changed
#     not-in-cycle-delta
#     block-fallback
#   reason-tokens: end
#   reason-record-shape: source: <heading> | head: <hash> | result: <line> | via: <basis>
#     — an interpolated citation, NOT a token; it names the covering entry a
#       suite inherited from, and is recorded on a green-tree-use entry as the
#       fixed token `covered-by-source` rather than verbatim.
#
# Citation basis: the block below is the ONE normative home of the `via:`
#         vocabulary — WHICH admission path produced a citation. It is declared
#         beside the reason tokens and held to the body by the same mirrored
#         pair of agreement legs (emitted subset-of declared, declared subset-of
#         emitted); adjacency to `reason-tokens` confers none of that on its own.
#         It exists because the two runs of the suite-grained-invalidation
#         control pair are textually identical in stderr EXCEPT for `via:`, so a
#         basis emitted that no declaration names leaves that control group
#         unreadable while both runs still pass.
#
#   citation-basis: begin
#     tree
#     shared-tree
#     input-hash
#     reach
#   citation-basis: end
#
#     tree        — the local whole-tree fast path: the last ledger entry of the
#                   cycle certifies the captured tree itself.
#     shared-tree — a repo-scoped SHARED entry at the captured tree, minted by
#                   some other issue. The cross-issue cold start this removes.
#     input-hash  — the covering entry's per-suite input hash equals this suite's
#                   input hash at the captured tree, so no delta restricted to
#                   the suite's input closure can be non-empty.
#     reach       — the shipped reach test against the covering head answered
#                   "not selected".
#
# A `green-tree-use` entry records every basis as the single fixed token
# `covered-by-source`: the ledger's vocabulary does not grow with this one.
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
# shellcheck source=scripts/test/green-tree-store.sh
. "$SCRIPT_DIR/green-tree-store.sh"

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

# `entry_result_is_pass` — "this `result` field states a pass" — is NOT defined
# here. It lives in scripts/test/green-tree-store.sh, sourced above: the ledger
# and the shared store admit an entry on the same question, so the admission
# test has one definition site rather than one copy per store.

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
  # `--include-worktree` is passed HERE and only here: the capture point
  # verifies the working tree, so the change this cycle is answering for is
  # committed AND uncommitted, and a committed-only candidate set would inherit
  # a suite whose subject is dirty. The reach test below asks a historical
  # question and deliberately does not pass it.
  local sel_err sel_out sel_rc
  if [ "$mode" = all ]; then
    is_candidate=()
    for suite in ${enumerated[@]+"${enumerated[@]}"}; do is_candidate["$suite"]=1; done
  else
    sel_err="$(mktemp)"
    sel_out="$(bash "$SCRIPT_DIR/select-suites.sh" --root "$root" --event pull_request --include-worktree 2>"$sel_err")"
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
  # Per field: tree and head must be hash-shaped, and worktree admits the single
  # value `clean` — the writer suppresses the entry entirely at a dirty capture
  # point, so any other value is a ledger no writer produces.
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
         || [ "$e_wt" != clean ]; then
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
          val="$(trim_ws "$val")"
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

  local n_ledger=${#entry_headings[@]}

  # --- Shared store: the repo-scoped cache OTHER issues minted -------------
  # The per-issue ledger is the only local source; without this read an issue's
  # empty ledger is a permanent cold start whatever a prior issue certified at
  # this very tree. Shared entries are appended to the SAME arrays as the ledger
  # entries, so every consumer below sees one entry space, with `shared_idx`
  # recording which of them came from the cache.
  #
  # A malformed entry here is SKIPPED WITH ONE WARNING, never a BLOCK — the
  # opposite of the ledger's disposition, deliberately. A malformed LOCAL entry
  # is a positive statement THIS cycle cannot read, and guessing at it widens
  # inheritance; skipping a foreign cache entry narrows, so BLOCKing every later
  # issue over another issue's file would fail in the wrong direction. An
  # unreadable store (absent, or refused for resolving inside the repo tree) is
  # likewise no entries, which resolves to executing.
  local shared_store="" scan_kind scan_heading scan_tree scan_head scan_suites scan_result
  local -a shared_idx=()
  shared_store="$(green_tree_store_path "$root" 2>/dev/null)" || shared_store=""
  if [ -n "$shared_store" ] && [ -f "$shared_store" ]; then
    while IFS=$'\t' read -r scan_kind scan_heading scan_tree scan_head scan_suites scan_result; do
      if [ "$scan_kind" != OK ]; then
        echo "suite-coverage: skipping a malformed shared-store entry — $scan_heading" >&2
        continue
      fi
      entry_headings+=("$scan_heading"); entry_trees+=("$scan_tree"); entry_heads+=("$scan_head")
      entry_results+=("$scan_result"); entry_suites+=("$scan_suites")
      shared_idx+=($(( ${#entry_headings[@]} - 1 )))
    done < <(green_tree_shared_scan "$shared_store")
  fi

  local n_entries=${#entry_headings[@]}

  # --- Token parse: `<path>[@<input-hash>]`, split at the LAST `@` ---------
  # A token with no `@` is the shipped bare-path form: it still folds and still
  # satisfies the fast path's membership test, but it carries NO certificate, so
  # the input-hash short-circuit cannot fire on it and every entry already
  # written answers exactly as today. `entry_paths[i]` is the entry's bare-path
  # projection — the form every membership test and the plan itself use, since a
  # token echoed into the plan would hand run-suites.sh a file that does not
  # exist.
  local i j tok tok_path plist
  local -a entry_paths=()
  local -A entry_suite_hash=()
  for (( i = 0; i < n_entries; i++ )); do
    plist=""
    for tok in ${entry_suites[$i]}; do
      tok_path="$(green_tree_suite_token_path "$tok")"
      [ -n "$tok_path" ] || continue
      plist="$plist${plist:+ }$tok_path"
      entry_suite_hash["$i|$tok_path"]="$(green_tree_suite_token_hash "$tok")"
    done
    entry_paths+=("$plist")
  done

  # --- Fold: suite -> the entry index at which it last passed --------------
  # File order, later supersedes earlier. Without this fold a narrow run would
  # ERASE the coverage an earlier wide run established, and the register would
  # be no more useful than the whole-tree key it replaces.
  #
  # The SHARED entries are folded FIRST and the ledger's second, so a local
  # entry of the current cycle supersedes a foreign certificate for the suites
  # it names. The cycle's own run is the more specific statement about this
  # cycle's tree, and the cache carries no authority to override it.
  local -A cover_idx=()
  for j in ${shared_idx[@]+"${shared_idx[@]}"}; do
    entry_result_is_pass "${entry_results[$j]}" || continue
    for tok_path in ${entry_paths[$j]}; do
      cover_idx["$tok_path"]=$j
    done
  done
  for (( i = 0; i < n_ledger; i++ )); do
    entry_result_is_pass "${entry_results[$i]}" || continue
    for tok_path in ${entry_paths[$i]}; do
      cover_idx["$tok_path"]=$i
    done
  done

  # --- Head resolvability, one definition site ----------------------------
  # Both the fast path and the fold cite an entry's head as the anchor a reader
  # re-derives, so both admit an entry on the same question: does the head name
  # a commit in the repository rooted at $root? Resolving in a subshell from
  # $root is the contract, not an incidental: the caller's cwd is not
  # necessarily the repository under test.
  head_resolves() { # <head hash> -> exit 0 when it names a commit
    (cd "$root" && git rev-parse --verify -q "$1^{commit}" >/dev/null 2>&1)
  }

  # --- Whole-tree fast path: the shipped three conditions, plus the head ---
  # resolvability this ADR deliberately tightens them with. The fast path is
  # otherwise the old predicate verbatim, and the added conjunct can only move a
  # suite from INHERIT to RUN — an unresolvable head makes the entry not
  # selectable, so fast_idx stays -1 and every candidate falls through to the
  # fold, which validates each head it lifts.
  local fast_idx=-1
  if [ -z "$dirty" ] && [ "$n_ledger" -gt 0 ]; then
    local last=$(( n_ledger - 1 ))
    if [ "${entry_trees[$last]}" = "$tree" ] && entry_result_is_pass "${entry_results[$last]}" \
       && head_resolves "${entry_heads[$last]}"; then
      fast_idx=$last
    fi
  fi

  # --- Shared tree match: the cross-issue arm of the fast path -------------
  # Unlike the local fast path this is a UNION over every matching shared entry,
  # not a last-entry rule. Tree equality is exact content identity, so recency
  # carries no information here and "last" is not even well-defined across
  # issues; and certificates are minted per phase-step run naming only the
  # suites that ran, so joint coverage by several entries is the ORDINARY
  # cross-issue case rather than a corner.
  #
  # `head_resolves` is a conjunct here for the same reason it is one on the
  # local fast path: a match CITES that head as the anchor a reader re-derives.
  # An entry declined here stays visible to the fold below, which validates
  # every head it lifts and executes that entry's suites with the named cause
  # `unresolvable-head` — so the decline moves a suite toward execution only.
  local -A shared_tree_cover=()
  if [ -z "$dirty" ]; then
    for j in ${shared_idx[@]+"${shared_idx[@]}"}; do
      [ "${entry_trees[$j]}" = "$tree" ] || continue
      entry_result_is_pass "${entry_results[$j]}" || continue
      head_resolves "${entry_heads[$j]}" || continue
      for tok_path in ${entry_paths[$j]}; do
        shared_tree_cover["$tok_path"]=$j
      done
    done
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

  local oot idx ans ih cur_ih
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
    # The candidate set is selected with `--include-worktree`, so "this cycle's
    # delta" here is the committed one unioned with the uncommitted worktree —
    # a suite whose subject is dirty is a candidate and falls through to Step 3.
    if [ -z "${is_candidate[$suite]:-}" ]; then
      decision["$suite"]=INHERIT; record["$suite"]="not-in-cycle-delta"; continue
    fi
    # Step 3 — unchanged from the shipped predicate.
    if [ -n "$dirty" ]; then
      decision["$suite"]=RUN; record["$suite"]="dirty-worktree"; continue
    fi
    # Step 4 — whole-tree fast path. The membership test is a PARSED lookup over
    # the entry's bare-path projection, not a substring match on a space-padded
    # field: `" $suite "` cannot appear in a field whose tokens carry an `@`
    # suffix, so this is a correctness requirement of the token grammar rather
    # than a cleanup.
    if [ "$fast_idx" -ge 0 ] && [ -n "${entry_suite_hash[$fast_idx|$suite]+set}" ]; then
      decision["$suite"]=INHERIT
      record["$suite"]="source: ${entry_headings[$fast_idx]} | head: ${entry_heads[$fast_idx]} | result: ${entry_results[$fast_idx]} | via: tree"
      continue
    fi
    # Step 5 — shared tree match. A certificate minted by another issue at this
    # exact tree. It comes after the local fast path and before the fold, and it
    # is the path that removes the cross-issue cold start.
    idx="${shared_tree_cover[$suite]:-}"
    if [ -n "$idx" ]; then
      decision["$suite"]=INHERIT
      record["$suite"]="source: ${entry_headings[$idx]} | head: ${entry_heads[$idx]} | result: ${entry_results[$idx]} | via: shared-tree"
      continue
    fi
    # Steps 6-9 — fold, head validation, input-hash short-circuit, reach test.
    idx="${cover_idx[$suite]:-}"
    if [ -z "$idx" ]; then
      decision["$suite"]=RUN
      if [ "$n_entries" -eq 0 ]; then record["$suite"]="no-entry"; else record["$suite"]="no-coverage"; fi
      continue
    fi
    local h="${entry_heads[$idx]}"
    if ! head_resolves "$h"; then
      decision["$suite"]=RUN; record["$suite"]="unresolvable-head"; continue
    fi
    # Step 8 — input-hash short-circuit, deliberately kept BEHIND the head
    # check. The comparison itself needs no resolvable head, so admitting one
    # here would raise the hit rate — and would produce an inheritance whose
    # cited anchor no reader can re-derive, which is precisely the tightening
    # ADR-0019 decision 2 introduced.
    #
    # Why it is sound rather than a widening loophole: the input closure is
    # DEFINITIONALLY the path set the selection predicate reads, so if every
    # closure member's blob is identical at the covering tree and at the
    # captured tree, no delta restricted to that closure can be non-empty and
    # the selector cannot select the suite. It is strictly MORE defined than the
    # reach test in the two places that test degenerates — an empty delta, which
    # the selector defines as "select everything", and a non-ancestor head,
    # where three-dot semantics answer a different question — because it uses
    # neither a delta nor ancestry, only content at two trees.
    ih="${entry_suite_hash[$idx|$suite]:-}"
    if [ -n "$ih" ]; then
      cur_ih="$(suite_input_hash "$root" "$tree" "$suite" 2>/dev/null || true)"
      if [ -n "$cur_ih" ] && [ "$cur_ih" = "$ih" ]; then
        decision["$suite"]=INHERIT
        record["$suite"]="source: ${entry_headings[$idx]} | head: $h | result: ${entry_results[$idx]} | via: input-hash"
        continue
      fi
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
        record["$suite"]="source: ${entry_headings[$idx]} | head: $h | result: ${entry_results[$idx]} | via: reach"
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

fx_entry() { # <ledger> <cycle> <tree> <head> <suites> [result] [worktree]
  # worktree defaults to clean (the only value the shipped writer produces).
  # The sentinel `omit` suppresses the line entirely, for the absent-field
  # disposition no value parameter can express (issue #112 cycle 3).
  local wt="${7:-clean}"
  {
    printf '### green-tree | cycle: %s | runner: VERIFY step 1\n' "$2"
    printf -- '- tree: %s\n' "$3"
    printf -- '- head: %s\n' "$4"
    if [ "$wt" != omit ]; then
      printf -- '- worktree: %s\n' "$wt"
    fi
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

# ---------------------------------------------------------------------------
# Issue #130 fixture builders — the repo-scoped shared store and the per-suite
# input-hash key. Every helper below drives a SHIPPED derivation rather than
# re-typing one: the repository key comes from `cleanup-issue.sh
# --print-repo-key` taken with its CWD at the fixture root (the CWD is a term
# of that call, not an incidental — a key taken elsewhere answers for THIS
# repository and the resulting permanent cold start is indistinguishable from
# correct fail-safe behaviour), and the input hash comes from the shipped
# `suite_input_hash`, never from a second implementation here.
# ---------------------------------------------------------------------------
CLEANUP_WRAPPER="$SCRIPT_DIR/../cleanup/cleanup-issue.sh"

fx_repo_key() { # <dir> -> the shipped repository key for the fixture at <dir>
  (cd "$1" && bash "$CLEANUP_WRAPPER" --print-repo-key 2>/dev/null)
}

fx_store_path() { # <archive-root> <dir> -> the shared register path
  printf '%s/%s/green-trees/register.md' "$1" "$(fx_repo_key "$2")"
}

fx_store_init() { # <archive-root> <dir> -> creates and echoes an empty store
  local p; p="$(fx_store_path "$1" "$2")"
  mkdir -p "$(dirname "$p")"
  : > "$p"
  printf '%s' "$p"
}

# fx_shared_entry <store> <issue> <cycle> <tree> <head> <suites> [result] [worktree]
# The shared grammar of the feature design: marker `### green-tree-shared | `,
# deliberately NOT the ledger marker, and `authority: Green-tree register
# (shared store)`.
fx_shared_entry() {
  local wt="${8:-clean}"
  {
    printf '### green-tree-shared | issue: #%s | cycle: %s | runner: VERIFY step 1\n' "$2" "$3"
    printf -- '- tree: %s\n' "$4"
    printf -- '- head: %s\n' "$5"
    if [ "$wt" != omit ]; then
      printf -- '- worktree: %s\n' "$wt"
    fi
    printf -- '- suites: %s\n' "$6"
    printf -- '- result: %s\n' "${7:-run-suites: 3 passed, 0 failed, 0 timed out, of 3 executed}"
    printf -- '- authority: Green-tree register (shared store)\n'
    printf '\n'
  } >> "$1"
}

# fx_input_hash <root> <tree> <suite> — the SHIPPED single site, sourced from
# whichever library owns it. Never re-typed here: a second implementation of
# the closure would agree on the day it was written and drift afterwards, and
# the leg would then be testing itself.
fx_input_hash() {
  (
    # shellcheck source=/dev/null
    . "$SCRIPT_DIR/suite-manifest.sh" 2>/dev/null
    if [ -f "$SCRIPT_DIR/green-tree-store.sh" ]; then
      # shellcheck source=/dev/null
      . "$SCRIPT_DIR/green-tree-store.sh" 2>/dev/null
    fi
    command -v suite_input_hash >/dev/null 2>&1 || exit 1
    suite_input_hash "$1" "$2" "$3"
  )
}

# fx_tokens <root> <tree> <suite> [<suite> ...] -> "<path>@<hash> ..."
fx_tokens() {
  local root="$1" tree="$2" s out=""
  shift 2
  for s in "$@"; do
    out="$out${out:+ }$s@$(fx_input_hash "$root" "$tree" "$s")"
  done
  printf '%s' "$out"
}

# st_run_shared <archive-root> <dir> <ledger> <cycle> <mode> — st_run with the
# store root redirected to a scratch directory. Reading or writing the live
# store is not hermetic (a genuine prior-cycle entry could make an inherit leg
# pass for a reason the leg did not create) and mutates production inheritance
# state, so every leg owns its own root.
st_run_shared() {
  local err; err="$(mktemp)"
  ST_PLAN="$(AUTOFLOW_ARCHIVE_ROOT="$1" bash "$SCRIPT_DIR/suite-coverage.sh" \
    --root "$2" --ledger "$3" --cycle "$4" --candidates "$5" 2>"$err")"
  ST_RC=$?
  ST_REC="$(cat "$err")"
  rm -f "$err"
}

# st_via <suite-regex> -> the citation basis the record carries, or empty
st_via() { st_reason "$1" | grep -oE 'via: [a-z][a-z-]*' | sed 's/^via: //'; }

# st_has_via <basis> -> true when ANY record carries that basis
st_has_via() { printf '%s\n' "$ST_REC" | grep -qE "via: $1( |\$)"; }

self_test() {
  local d ledger tree head

  # Hermetic store root for the WHOLE self-test (issue #130). The shared store
  # resolves under $AUTOFLOW_ARCHIVE_ROOT, which defaults into the operator's
  # real home directory (scripts/cleanup/cleanup-issue.sh), so a leg that did
  # not redirect it could inherit from a genuine prior-cycle certificate — an
  # inherit leg passing for a reason the leg did not create — and could mutate
  # production inheritance state. Every leg below therefore runs under a
  # scratch root: the legs that seed a store name their own, and the ones that
  # do not are covered by this default so their `no-entry` expectations stay
  # decidable. This is a design property, not a fake: the real store library
  # reads a real file at a real path.
  local st_default_archive; st_default_archive="$(mktemp -d)"
  export AUTOFLOW_ARCHIVE_ROOT="$st_default_archive"

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

  # --- DIRTY-CANDIDATE leg: a suite whose subject is modified only in the
  # worktree, untouched by the committed cycle delta, must RUN with reason
  # dirty-worktree — never INHERIT not-in-cycle-delta (issue #112 cycle 2
  # review finding: the candidate set was committed-history-only, so Step 8
  # inherited a suite Step 3 never got to see). The suite neither delta
  # touches is the discriminator against the rejected branch-reorder fix: it
  # must still read not-in-cycle-delta, in the same run.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  fx_commit "$d" docs/subject-a.md "committed touch a"
  printf '%s\n' "uncommitted $(date +%s%N)" >> "$d/docs/subject-c.md"
  st_run "$d" "$ledger" 1 selection
  if st_reason 'tests/test-fx-cov-c\.sh' | grep -qE '^RUN: .* dirty-worktree'; then
    st_ok "DIRTY-CANDIDATE leg" "an uncommitted-only subject edit is planned for execution, reason dirty-worktree"
  else
    st_fail "DIRTY-CANDIDATE leg" "expected test-fx-cov-c.sh RUN dirty-worktree, got: $ST_REC"
  fi
  if st_reason 'tests/test-fx-cov-b\.sh' | grep -qF 'not-in-cycle-delta'; then
    st_ok "DIRTY-CANDIDATE leg (branch-reorder discriminator)" "the suite neither delta touches still inherits not-in-cycle-delta, distinguishing the accepted fix from a dirty-branch reorder"
  else
    st_fail "DIRTY-CANDIDATE leg (branch-reorder discriminator)" "expected test-fx-cov-b.sh INHERIT not-in-cycle-delta, got: $ST_REC"
  fi
  if [ "$(printf '%s\n' "$ST_REC" | grep -cE '^(RUN|INHERIT): ')" -eq 3 ] \
     && [ "$(printf '%s\n' "$ST_PLAN" | grep -c .)" = "$(printf '%s\n' "$ST_REC" | grep -cE '^RUN: ')" ]; then
    st_ok "DIRTY-CANDIDATE leg (partition)" "the total-partition contract holds under a dirty tree: every enumerated suite carries exactly one record and the plan is exactly the RUN-recorded set"
  else
    st_fail "DIRTY-CANDIDATE leg (partition)" "expected 3 records and plan == RUN-recorded set, got plan: $(printf '%s' "$ST_PLAN" | tr '\n' ' ') rec: $ST_REC"
  fi
  rm -rf "$d"

  # --- DIRTY-CANDIDATE clean-tree control: with the uncommitted edit
  # reverted, the same suite is INHERIT not-in-cycle-delta and the plan stays
  # narrowed — without this control the leg above would pass equally under a
  # resolver that runs everything.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  fx_commit "$d" docs/subject-a.md "committed touch a"
  st_run "$d" "$ledger" 1 selection
  if [ "$ST_PLAN" = "tests/test-fx-cov-a.sh" ] \
     && st_reason 'tests/test-fx-cov-c\.sh' | grep -qF 'not-in-cycle-delta'; then
    st_ok "DIRTY-CANDIDATE clean-tree control" "with no uncommitted edit, the plan stays narrowed to the committed delta"
  else
    st_fail "DIRTY-CANDIDATE clean-tree control" "expected only test-fx-cov-a.sh planned and c INHERIT not-in-cycle-delta, got: $ST_REC"
  fi
  rm -rf "$d"

  # --- PARTITION-ALL-DIRTY leg: --candidates all makes no selection call, so
  # the cycle-2 candidate-set amendment reaches nothing on that path — the
  # dirty-all record set is identical to the shipped pre-amendment dirty-all
  # behaviour (every enumerated suite RUN dirty-worktree, unconditionally).
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  printf '%s\n' "uncommitted $(date +%s%N)" >> "$d/docs/subject-c.md"
  st_run "$d" "$ledger" 1 all
  if [ "$(printf '%s\n' "$ST_REC" | grep -cE '^RUN: .* dirty-worktree$')" -eq 3 ] \
     && [ "$(printf '%s\n' "$ST_PLAN" | grep -c .)" -eq 3 ]; then
    st_ok "PARTITION-ALL-DIRTY leg" "under --candidates all a dirty worktree still plans every enumerated suite via the unmodified dirty branch"
  else
    st_fail "PARTITION-ALL-DIRTY leg" "expected 3 RUN dirty-worktree records, got: $ST_REC"
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

  # --- MALFORMED-WORKTREE leg (a): a dirty-tagged entry BLOCKs rather than
  # being selected, and folds nothing in. The BLOCK observable triple mirrors
  # the shipped BLOCK leg (malformed entry) above; the fourth assertion is
  # this leg's own — a BLOCK short-circuits before the per-suite fold ever
  # runs, so no INHERIT record can cite the blocked entry (issue #112 cycle 3).
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"; head="$(git -C "$d" rev-parse HEAD)"
  fx_entry "$ledger" 1 "$tree" "$head" \
    "tests/test-fx-cov-a.sh tests/test-fx-cov-b.sh tests/test-fx-cov-c.sh" \
    "run-suites: 3 passed, 0 failed, 0 timed out, of 3 executed" dirty
  st_run "$d" "$ledger" 1 all
  if [ "$ST_RC" -ne 0 ] && [ "$(printf '%s\n' "$ST_PLAN" | grep -c .)" -eq 3 ] \
     && [ "$(printf '%s\n' "$ST_REC" | grep -cE '^RUN: .* block-fallback$')" -eq 3 ] \
     && [ "$(printf '%s\n' "$ST_REC" | grep -cE '^INHERIT: ')" -eq 0 ]; then
    st_ok "MALFORMED-WORKTREE leg (dirty blocks)" "a worktree: dirty entry BLOCKs the whole enumerated set and folds nothing in"
  else
    st_fail "MALFORMED-WORKTREE leg (dirty blocks)" "expected 3 block-fallback records, zero INHERIT records, and a non-zero exit, got rc=$ST_RC: $ST_REC"
  fi
  rm -rf "$d"

  # --- MALFORMED-WORKTREE leg (b): clean control. The identical fixture and
  # entry, differing only in that one value, must still inherit — without this
  # control a dirty half broken for an unrelated reason goes green for the
  # wrong reason.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"; head="$(git -C "$d" rev-parse HEAD)"
  fx_entry "$ledger" 1 "$tree" "$head" \
    "tests/test-fx-cov-a.sh tests/test-fx-cov-b.sh tests/test-fx-cov-c.sh" \
    "run-suites: 3 passed, 0 failed, 0 timed out, of 3 executed" clean
  st_run "$d" "$ledger" 1 all
  if [ "$ST_RC" -eq 0 ] && [ -z "$ST_PLAN" ] \
     && [ "$(printf '%s\n' "$ST_REC" | grep -cE '^INHERIT: ')" -eq 3 ] \
     && st_reason 'tests/test-fx-cov-a\.sh' | grep -qF '### green-tree | cycle: 1'; then
    st_ok "MALFORMED-WORKTREE leg (clean control)" "the identical entry with worktree: clean still inherits every suite, citing the entry as source"
  else
    st_fail "MALFORMED-WORKTREE leg (clean control)" "expected an empty plan and 3 INHERIT records citing the entry, got rc=$ST_RC: $ST_REC"
  fi
  rm -rf "$d"

  # --- MALFORMED-WORKTREE leg (c): an unrecognised value still BLOCKs — the
  # regression observer proving the edit narrowed the accepted set rather than
  # collapsing the whole condition it lives in.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"; head="$(git -C "$d" rev-parse HEAD)"
  fx_entry "$ledger" 1 "$tree" "$head" \
    "tests/test-fx-cov-a.sh tests/test-fx-cov-b.sh tests/test-fx-cov-c.sh" \
    "run-suites: 3 passed, 0 failed, 0 timed out, of 3 executed" murky
  st_run "$d" "$ledger" 1 all
  if [ "$ST_RC" -ne 0 ] && [ "$(printf '%s\n' "$ST_PLAN" | grep -c .)" -eq 3 ] \
     && [ "$(printf '%s\n' "$ST_REC" | grep -cE '^RUN: .* block-fallback$')" -eq 3 ]; then
    st_ok "MALFORMED-WORKTREE leg (unrecognised value)" "a worktree value that is neither clean nor dirty still BLOCKs"
  else
    st_fail "MALFORMED-WORKTREE leg (unrecognised value)" "expected 3 block-fallback records and a non-zero exit, got rc=$ST_RC: $ST_REC"
  fi
  rm -rf "$d"

  # --- MALFORMED-WORKTREE leg (d): the absent-field disposition is unchanged
  # — no `worktree` line at all is still the silent mismatch (no-entry), never
  # the BLOCK this cycle adds for a present-but-unreadable value.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"; head="$(git -C "$d" rev-parse HEAD)"
  fx_entry "$ledger" 1 "$tree" "$head" \
    "tests/test-fx-cov-a.sh tests/test-fx-cov-b.sh tests/test-fx-cov-c.sh" \
    "run-suites: 3 passed, 0 failed, 0 timed out, of 3 executed" omit
  st_run "$d" "$ledger" 1 all
  if [ "$ST_RC" -eq 0 ] && [ "$(printf '%s\n' "$ST_PLAN" | grep -c .)" -eq 3 ] \
     && [ "$(printf '%s\n' "$ST_REC" | grep -cE '^RUN: ')" -eq 3 ] \
     && st_reason 'tests/test-fx-cov-a\.sh' | grep -qF 'no-entry'; then
    st_ok "MALFORMED-WORKTREE leg (absent field)" "an entry with no worktree line at all stays silently non-selected, cause no-entry"
  else
    st_fail "MALFORMED-WORKTREE leg (absent field)" "expected 3 RUN records with cause no-entry, got rc=$ST_RC: $ST_REC"
  fi
  rm -rf "$d"

  # --- FAST-PATH-UNRESOLVABLE-HEAD leg (issue #112 cycle 5 review finding):
  # the whole-tree fast path selects an entry on tree equality and a passing
  # result alone, with no check that its `head` resolves — unlike the fold,
  # which validates the same field before use. An entry whose tree matches the
  # capture but whose head names no object must fall through to execution,
  # never cite the unresolvable head as an inheritance anchor. Run under
  # --candidates selection, in the same fixture, so the same run also proves
  # the non-candidate boundary (Step 8) is unaffected: it fires ahead of the
  # fast path regardless of the entry's head validity.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  fx_commit "$d" docs/subject-a.md "committed touch a"
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"
  fx_entry "$ledger" 1 "$tree" "cafebabecafebabecafebabecafebabecafebabe" \
    "tests/test-fx-cov-a.sh tests/test-fx-cov-b.sh tests/test-fx-cov-c.sh"
  st_run "$d" "$ledger" 1 selection
  if ! printf '%s\n' "$ST_REC" | grep -q 'head: cafebabecafebabecafebabecafebabecafebabe'; then
    st_ok "FAST-PATH-UNRESOLVABLE-HEAD leg (no citation)" "no record cites the unresolvable head as an inheritance anchor"
  else
    st_fail "FAST-PATH-UNRESOLVABLE-HEAD leg (no citation)" "expected no record to cite the bogus head, got: $ST_REC"
  fi
  if [ "$ST_RC" -eq 0 ] && st_reason 'tests/test-fx-cov-a\.sh' | grep -qE '^RUN: .* unresolvable-head'; then
    st_ok "FAST-PATH-UNRESOLVABLE-HEAD leg (executes)" "a matching-tree entry with an unresolvable head falls through to execution at exit 0, not a BLOCK"
  else
    st_fail "FAST-PATH-UNRESOLVABLE-HEAD leg (executes)" "expected test-fx-cov-a.sh RUN unresolvable-head at rc 0, got rc=$ST_RC: $ST_REC"
  fi
  if st_reason 'tests/test-fx-cov-b\.sh' | grep -qF 'not-in-cycle-delta' \
     && ! st_reason 'tests/test-fx-cov-b\.sh' | grep -q 'head:' \
     && st_reason 'tests/test-fx-cov-c\.sh' | grep -qF 'not-in-cycle-delta' \
     && ! st_reason 'tests/test-fx-cov-c\.sh' | grep -q 'head:'; then
    st_ok "FAST-PATH-UNRESOLVABLE-HEAD leg (non-candidate boundary)" "suites outside the cycle delta still inherit not-in-cycle-delta, citing no head, unaffected by the invalid head elsewhere in the entry"
  else
    st_fail "FAST-PATH-UNRESOLVABLE-HEAD leg (non-candidate boundary)" "expected b and c INHERIT not-in-cycle-delta with no head citation, got: $ST_REC"
  fi
  rm -rf "$d"

  # =========================================================================
  # Issue #130 — the repo-scoped shared store and the per-suite input-hash key
  # =========================================================================
  local st_ar store shared_head shared_tree old_head old_tree

  # --- SHARED-COLD-START leg (acceptance criterion 1, hermetic half): a fresh
  # issue on an unchanged tree, with an entry present ONLY in the shared store
  # and an EMPTY per-issue ledger, plans nothing. This is the cross-issue cold
  # start the change removes: today the resolver's only entry source is the
  # issue's own ledger, so an empty ledger is a permanent cold start whatever
  # a prior issue certified. The `via: shared-tree` assertion is what makes the
  # inheritance attributable to the shared arm rather than to any local path.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  st_ar="$(mktemp -d)"; store="$(fx_store_init "$st_ar" "$d")"
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"; head="$(git -C "$d" rev-parse HEAD)"
  fx_shared_entry "$store" 101 1 "$tree" "$head" \
    "tests/test-fx-cov-a.sh tests/test-fx-cov-b.sh tests/test-fx-cov-c.sh"
  st_run_shared "$st_ar" "$d" "$ledger" 1 all
  if [ "$ST_RC" -eq 0 ] && [ -z "$ST_PLAN" ] \
     && [ "$(printf '%s\n' "$ST_REC" | grep -cE '^INHERIT: ')" -eq 3 ] \
     && [ "$(printf '%s\n' "$ST_REC" | grep -cE 'via: shared-tree( |$)')" -eq 3 ]; then
    st_ok "SHARED-COLD-START leg" "an entry in the shared store alone, with an empty per-issue ledger, yields an empty run set with every suite recorded INHERIT via: shared-tree"
  else
    st_fail "SHARED-COLD-START leg" "expected an empty plan and 3 INHERIT records citing via: shared-tree, got rc=$ST_RC plan='$(printf '%s' "$ST_PLAN" | tr '\n' ' ')': $ST_REC"
  fi
  if st_reason 'tests/test-fx-cov-a\.sh' | grep -qF '### green-tree-shared | issue: #101'; then
    st_ok "SHARED-COLD-START leg (citation)" "the inherited record cites the shared entry's own heading, so the certificate a reader re-derives names the issue that minted it"
  else
    st_fail "SHARED-COLD-START leg (citation)" "expected the record to cite the shared entry heading, got: $ST_REC"
  fi
  rm -rf "$d" "$st_ar"

  # --- SUITE-GRAINED-INVALIDATION leg, hashed arm (acceptance criterion 2):
  # one subject moved, so exactly the suite whose input closure contains it is
  # invalidated. The other two carry an input hash that still matches at the
  # captured tree and take the step-8 short-circuit, recorded via: input-hash.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  old_head="$(git -C "$d" rev-parse HEAD)"; old_tree="$(git -C "$d" rev-parse "HEAD^{tree}")"
  fx_commit "$d" docs/subject-a.md "move subject a"
  fx_entry "$ledger" 1 "$old_tree" "$old_head" \
    "$(fx_tokens "$d" "$old_tree" tests/test-fx-cov-a.sh tests/test-fx-cov-b.sh tests/test-fx-cov-c.sh)"
  st_run "$d" "$ledger" 1 all
  if [ "$ST_PLAN" = "tests/test-fx-cov-a.sh" ] \
     && st_reason 'tests/test-fx-cov-a\.sh' | grep -qE '^RUN: .* reach-changed' \
     && [ "$(st_via 'tests/test-fx-cov-b\.sh')" = input-hash ] \
     && [ "$(st_via 'tests/test-fx-cov-c\.sh')" = input-hash ]; then
    st_ok "SUITE-GRAINED leg (hashed arm)" "the suite whose ci-subject target moved runs as reach-changed while the same-input suites inherit via: input-hash"
  else
    st_fail "SUITE-GRAINED leg (hashed arm)" "expected only test-fx-cov-a.sh planned (reach-changed) with b and c inheriting via: input-hash, got plan='$(printf '%s' "$ST_PLAN" | tr '\n' ' ')': $ST_REC"
  fi
  # The plan is a path list run-suites.sh --selected consumes directly, so the
  # `@<input-hash>` suffix must live in the ENTRY and never reach stdout — a
  # decorated plan hands the runner a file that does not exist, a failure that
  # is silent here and only surfaces one layer downstream.
  if [ "$ST_PLAN" = "tests/test-fx-cov-a.sh" ] && ! printf '%s\n' "$ST_PLAN" | grep -q '@'; then
    st_ok "PLAN-UNDECORATED leg" "the narrowed plan carries bare repo-relative paths while the covering entry carries @<input-hash> tokens"
  else
    st_fail "PLAN-UNDECORATED leg" "expected the narrowed plan to be the bare path tests/test-fx-cov-a.sh, got: $(printf '%s' "$ST_PLAN" | tr '\n' ' ')"
  fi
  rm -rf "$d"

  # --- SUITE-GRAINED-INVALIDATION leg, bare-token control: the SAME fixture
  # state and the same covering entry, its tokens written in the shipped bare
  # form. A bare token still folds, but carries no input-hash certificate, so
  # the step-8 short-circuit cannot fire on it and every inheritance here is
  # the shipped reach answer. Without this half the hashed arm above passes
  # equally under a resolver that inherits everything it does not run.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  old_head="$(git -C "$d" rev-parse HEAD)"; old_tree="$(git -C "$d" rev-parse "HEAD^{tree}")"
  fx_commit "$d" docs/subject-a.md "move subject a"
  fx_entry "$ledger" 1 "$old_tree" "$old_head" \
    "tests/test-fx-cov-a.sh tests/test-fx-cov-b.sh tests/test-fx-cov-c.sh"
  st_run "$d" "$ledger" 1 all
  if [ "$ST_PLAN" = "tests/test-fx-cov-a.sh" ] \
     && ! st_has_via 'input-hash' \
     && [ "$(st_via 'tests/test-fx-cov-b\.sh')" = reach ] \
     && [ "$(st_via 'tests/test-fx-cov-c\.sh')" = reach ]; then
    st_ok "SUITE-GRAINED leg (bare-token control)" "a bare token never carries an input-hash certificate: the same state inherits by the reach answer, recorded via: reach"
  else
    st_fail "SUITE-GRAINED leg (bare-token control)" "expected no via: input-hash record and b/c inheriting via: reach, got plan='$(printf '%s' "$ST_PLAN" | tr '\n' ' ')': $ST_REC"
  fi
  rm -rf "$d"

  # --- SUITE-GRAINED-INVALIDATION leg, whole-tree-key control: the shipped
  # key, evaluated at the tree it certifies. This is the control group the
  # criterion names — under a whole-tree key inheritance is all-or-nothing,
  # recorded via: tree, and it is the only basis the shipped resolver can
  # report. Read against the hashed arm above, the pair records exactly what
  # the change buys: a basis that survives a tree the whole-tree key discards.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"; head="$(git -C "$d" rev-parse HEAD)"
  fx_entry "$ledger" 1 "$tree" "$head" \
    "tests/test-fx-cov-a.sh tests/test-fx-cov-b.sh tests/test-fx-cov-c.sh"
  st_run "$d" "$ledger" 1 all
  if [ -z "$ST_PLAN" ] && [ "$(printf '%s\n' "$ST_REC" | grep -cE 'via: tree( |$)')" -eq 3 ]; then
    st_ok "SUITE-GRAINED leg (whole-tree-key control)" "the shipped whole-tree key inherits every covered suite at the tree it certifies, recorded via: tree"
  else
    st_fail "SUITE-GRAINED leg (whole-tree-key control)" "expected an empty plan and 3 records citing via: tree, got plan='$(printf '%s' "$ST_PLAN" | tr '\n' ' ')': $ST_REC"
  fi
  rm -rf "$d"

  # --- HASHED-TOKEN-FAST-PATH leg (bare-token disposition, second half): the
  # whole-tree fast path must still find a suite whose token carries an `@`
  # suffix. The shipped membership test is a substring match on a space-padded
  # field, and `" $suite "` cannot appear in a field whose tokens carry a
  # suffix — so the parsed lookup is a correctness requirement of the token
  # change, not a cleanup. A fixture set whose entries all stay bare exercises
  # neither half.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"; head="$(git -C "$d" rev-parse HEAD)"
  fx_entry "$ledger" 1 "$tree" "$head" \
    "$(fx_tokens "$d" "$tree" tests/test-fx-cov-a.sh tests/test-fx-cov-b.sh tests/test-fx-cov-c.sh)"
  st_run "$d" "$ledger" 1 all
  if [ "$ST_RC" -eq 0 ] && [ -z "$ST_PLAN" ] \
     && [ "$(printf '%s\n' "$ST_REC" | grep -cE '^INHERIT: ')" -eq 3 ]; then
    st_ok "HASHED-TOKEN-FAST-PATH leg" "an entry whose tokens carry @<input-hash> is still found by the whole-tree fast path — the membership test is a parsed lookup, not a padded substring match"
  else
    st_fail "HASHED-TOKEN-FAST-PATH leg" "expected an empty plan and 3 INHERIT records, got rc=$ST_RC plan='$(printf '%s' "$ST_PLAN" | tr '\n' ' ')': $ST_REC"
  fi
  rm -rf "$d"

  # --- LIB-CLOSURE leg (DISPATCH directive D1): the only difference between
  # the covering tree and the captured tree is a file under tests/lib/. The
  # selection predicate selects EVERY suite when a shared library moves, so an
  # input closure omitting tests/lib/** would be narrower than the selection
  # boundary and the "inheritance boundary IS the selection boundary" contract
  # would become false rather than tightened. No suite may take the step-8
  # short-circuit here, however its own ci-subject closure looks.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  old_head="$(git -C "$d" rev-parse HEAD)"; old_tree="$(git -C "$d" rev-parse "HEAD^{tree}")"
  fx_commit "$d" tests/lib/harness.sh "move the shared library"
  fx_entry "$ledger" 1 "$old_tree" "$old_head" \
    "$(fx_tokens "$d" "$old_tree" tests/test-fx-cov-a.sh tests/test-fx-cov-b.sh tests/test-fx-cov-c.sh)"
  st_run "$d" "$ledger" 1 all
  if ! st_has_via 'input-hash' \
     && [ "$(printf '%s\n' "$ST_PLAN" | grep -c .)" -eq 3 ] \
     && [ "$(printf '%s\n' "$ST_REC" | grep -cE '^RUN: .* reach-changed$')" -eq 3 ]; then
    st_ok "LIB-CLOSURE leg (D1)" "a tests/lib/ move invalidates every suite's input hash, so no suite short-circuits and all three execute as reach-changed"
  else
    st_fail "LIB-CLOSURE leg (D1)" "expected no via: input-hash record and 3 RUN reach-changed, got plan='$(printf '%s' "$ST_PLAN" | tr '\n' ' ')': $ST_REC"
  fi
  rm -rf "$d"

  # --- DECLARATION-BEATS-SHARED leg (acceptance criterion 3a): the declared
  # out-of-tree reader is tested FIRST, before any store read and any key
  # comparison, so it beats BOTH new paths exactly as it beats the shipped
  # fast path today. The entry here is in the shared store, at the captured
  # tree, and names the declaring suite with a matching input hash — every new
  # admission path is armed, and the declaration must still win.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  awk '{print} /^# budget-secs:/ && !done {print "# out-of-tree-inputs: yes"; done=1}' \
    "$d/tests/test-fx-cov-c.sh" > "$d/tests/test-fx-cov-c.sh.new" \
    && mv "$d/tests/test-fx-cov-c.sh.new" "$d/tests/test-fx-cov-c.sh"
  git -C "$d" add -A >/dev/null 2>&1
  git -C "$d" -c user.email=a@b.c -c user.name=a commit -q -m declare >/dev/null 2>&1
  st_ar="$(mktemp -d)"; store="$(fx_store_init "$st_ar" "$d")"
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"; head="$(git -C "$d" rev-parse HEAD)"
  fx_shared_entry "$store" 102 1 "$tree" "$head" \
    "$(fx_tokens "$d" "$tree" tests/test-fx-cov-a.sh tests/test-fx-cov-b.sh tests/test-fx-cov-c.sh)"
  st_run_shared "$st_ar" "$d" "$ledger" 1 all
  if [ "$ST_PLAN" = "tests/test-fx-cov-c.sh" ] \
     && st_reason 'tests/test-fx-cov-c\.sh' | grep -qF 'out-of-tree-inputs'; then
    st_ok "DECLARATION-BEATS-SHARED leg" "a declared out-of-tree reader executes even when the shared store holds a tree-matching entry naming it with a matching input hash"
  else
    st_fail "DECLARATION-BEATS-SHARED leg" "expected only test-fx-cov-c.sh planned with reason out-of-tree-inputs, got plan='$(printf '%s' "$ST_PLAN" | tr '\n' ' ')': $ST_REC"
  fi
  rm -rf "$d" "$st_ar"

  # --- SHARED-UNRESOLVABLE-HEAD leg (acceptance criterion 4, shared arm): the
  # new read path must apply the head_resolves conjunct its ledger sibling
  # applies. A shared entry whose head names no commit is a named cause and
  # its suites execute; nothing may cite the unresolvable head as an anchor,
  # because the cited head is what a reader re-derives.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  st_ar="$(mktemp -d)"; store="$(fx_store_init "$st_ar" "$d")"
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"
  fx_shared_entry "$store" 103 1 "$tree" "cafebabecafebabecafebabecafebabecafebabe" \
    "tests/test-fx-cov-a.sh"
  st_run_shared "$st_ar" "$d" "$ledger" 1 all
  if [ "$ST_RC" -eq 0 ] \
     && st_reason 'tests/test-fx-cov-a\.sh' | grep -qE '^RUN: .* unresolvable-head' \
     && ! printf '%s\n' "$ST_REC" | grep -q 'cafebabecafebabecafebabecafebabecafebabe'; then
    st_ok "SHARED-UNRESOLVABLE-HEAD leg (shared arm)" "a shared entry whose head names no commit executes its suites with the named cause and is cited by nothing"
  else
    st_fail "SHARED-UNRESOLVABLE-HEAD leg (shared arm)" "expected test-fx-cov-a.sh RUN unresolvable-head at rc 0 with no citation of the bogus head, got rc=$ST_RC: $ST_REC"
  fi
  rm -rf "$d" "$st_ar"

  # --- SHARED-UNRESOLVABLE-HEAD leg (ahead of the short-circuit): the same
  # failure with the input-hash path ALSO armed — the entry carries a hash
  # that matches at the captured tree. The head check is deliberately kept
  # ahead of the short-circuit, so the answer must still be unresolvable-head;
  # an implementation that short-circuits first inherits from a certificate no
  # reader can re-derive.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  st_ar="$(mktemp -d)"; store="$(fx_store_init "$st_ar" "$d")"
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"
  fx_shared_entry "$store" 104 1 "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" \
    "cafebabecafebabecafebabecafebabecafebabe" \
    "$(fx_tokens "$d" "$tree" tests/test-fx-cov-a.sh)"
  st_run_shared "$st_ar" "$d" "$ledger" 1 all
  if [ "$ST_RC" -eq 0 ] \
     && st_reason 'tests/test-fx-cov-a\.sh' | grep -qE '^RUN: .* unresolvable-head'; then
    st_ok "SHARED-UNRESOLVABLE-HEAD leg (ahead of the short-circuit)" "a matching input hash does not admit an entry whose head names no commit — the head check stays ahead of the short-circuit"
  else
    st_fail "SHARED-UNRESOLVABLE-HEAD leg (ahead of the short-circuit)" "expected test-fx-cov-a.sh RUN unresolvable-head at rc 0, got rc=$ST_RC: $ST_REC"
  fi
  rm -rf "$d" "$st_ar"

  # --- SHARED-UNION legs (acceptance criterion 5): the shared arm is a UNION
  # over every matching entry, not the last-entry rule the local fast path
  # uses. Tree equality is exact content identity, so recency carries no
  # information across issues and "last" is not even well-defined there.
  # Certificates are minted per phase-step run naming only the suites that
  # ran, so joint coverage by several entries is the ordinary cross-issue
  # case. Each inheriting suite must cite ITS OWN contributing entry — a
  # last-entry implementation passes the disjoint half by accident and fails
  # the citation assertion.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  st_ar="$(mktemp -d)"; store="$(fx_store_init "$st_ar" "$d")"
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"; head="$(git -C "$d" rev-parse HEAD)"
  fx_shared_entry "$store" 201 1 "$tree" "$head" "tests/test-fx-cov-a.sh"
  fx_shared_entry "$store" 202 1 "$tree" "$head" "tests/test-fx-cov-b.sh"
  fx_shared_entry "$store" 203 1 "$tree" "$head" "tests/test-fx-cov-c.sh" \
    "run-suites: 2 passed, 1 failed, 0 timed out, of 3 executed"
  st_run_shared "$st_ar" "$d" "$ledger" 1 all
  if st_reason 'tests/test-fx-cov-a\.sh' | grep -qF '### green-tree-shared | issue: #201' \
     && st_reason 'tests/test-fx-cov-b\.sh' | grep -qF '### green-tree-shared | issue: #202'; then
    st_ok "SHARED-UNION leg (disjoint entries)" "two shared entries at one tree naming disjoint suites both contribute, each inherited suite citing its own entry"
  else
    st_fail "SHARED-UNION leg (disjoint entries)" "expected a to cite issue #201 and b to cite issue #202, got: $ST_REC"
  fi
  if [ "$ST_PLAN" = "tests/test-fx-cov-c.sh" ] \
     && st_reason 'tests/test-fx-cov-c\.sh' | grep -qE '^RUN: .* no-coverage'; then
    st_ok "SHARED-UNION leg (non-pass entry)" "a shared entry at the captured tree whose result is not a pass contributes nothing: the suites only it names execute, cause no-coverage"
  else
    st_fail "SHARED-UNION leg (non-pass entry)" "expected only test-fx-cov-c.sh planned with cause no-coverage, got plan='$(printf '%s' "$ST_PLAN" | tr '\n' ' ')': $ST_REC"
  fi
  rm -rf "$d" "$st_ar"

  # --- SHARED-MALFORMED leg (DISPATCH directive D5): a malformed SHARED entry
  # is skipped with one warning, never trusted and never a BLOCK. The
  # dispositions differ by store on purpose: the per-issue ledger is written
  # by this cycle and a malformed entry there is a positive statement this
  # cycle cannot read, so it BLOCKs; the shared store is written by other
  # issues and may outlive the grammar that wrote it, so one unreadable
  # certificate degrades to executing that certificate's suites rather than
  # halting every later issue. The well-formed sibling in the same store is
  # the discriminator: a resolver that BLOCKs, or that abandons the file at
  # the first bad entry, loses it.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  st_ar="$(mktemp -d)"; store="$(fx_store_init "$st_ar" "$d")"
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"; head="$(git -C "$d" rev-parse HEAD)"
  fx_shared_entry "$store" 301 1 "not-a-tree-hash" "$head" "tests/test-fx-cov-a.sh"
  fx_shared_entry "$store" 302 1 "$tree" "$head" "tests/test-fx-cov-b.sh"
  st_run_shared "$st_ar" "$d" "$ledger" 1 all
  if [ "$ST_RC" -eq 0 ] \
     && ! printf '%s\n' "$ST_REC" | grep -q '^BLOCK: ' \
     && st_reason 'tests/test-fx-cov-b\.sh' | grep -q '^INHERIT: ' \
     && st_reason 'tests/test-fx-cov-a\.sh' | grep -q '^RUN: '; then
    st_ok "SHARED-MALFORMED leg (D5, not a BLOCK)" "a malformed shared entry is never trusted and never BLOCKs; the well-formed sibling in the same store still contributes"
  else
    st_fail "SHARED-MALFORMED leg (D5, not a BLOCK)" "expected rc 0, no BLOCK, b inheriting and a running, got rc=$ST_RC: $ST_REC"
  fi
  if [ "$(printf '%s\n' "$ST_REC" | grep -cvE '^(RUN|INHERIT): ')" -eq 1 ] \
     && printf '%s\n' "$ST_REC" | grep -vE '^(RUN|INHERIT): ' | grep -qF '#301'; then
    st_ok "SHARED-MALFORMED leg (D5, one warning)" "exactly one non-record line is emitted, and it names the malformed entry so the operator can find it"
  else
    st_fail "SHARED-MALFORMED leg (D5, one warning)" "expected exactly one non-record stderr line naming the malformed entry, got: $(printf '%s\n' "$ST_REC" | grep -vE '^(RUN|INHERIT): ' | tr '\n' ' ')"
  fi
  rm -rf "$d" "$st_ar"

  # --- FOLD-PRECEDENCE leg (VERIFY step 3, U1): the coverage fold reads the
  # SHARED entries first and the ledger's second, so a local entry of the
  # current cycle supersedes a foreign certificate for the suites it names.
  # The cycle's own run is the more specific statement about this cycle's
  # tree, and the cache carries no authority to override it.
  #
  # Both entries key a tree that is NOT the captured one, so neither the local
  # fast path nor the shared tree match fires and the decision comes from the
  # fold alone; both heads ARE the captured head, so the reach test answers
  # `inherit` without a selector call and the citation is the only thing that
  # varies. The discriminator against "shared entries are simply ignored" is
  # the second assertion: a suite ONLY the shared entry names must still
  # inherit, citing it, in the same run.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  st_ar="$(mktemp -d)"; store="$(fx_store_init "$st_ar" "$d")"
  head="$(git -C "$d" rev-parse HEAD)"
  fx_shared_entry "$store" 601 1 "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" "$head" \
    "tests/test-fx-cov-a.sh tests/test-fx-cov-b.sh"
  fx_entry "$ledger" 1 "beefdeadbeefdeadbeefdeadbeefdeadbeefdead" "$head" \
    "tests/test-fx-cov-a.sh"
  st_run_shared "$st_ar" "$d" "$ledger" 1 all
  # The shared-contributes conjunct belongs INSIDE this assertion, not only in
  # the one below it: "cites the ledger, not the shared entry" is satisfied
  # trivially by a resolver that never reads the shared store at all, which is
  # exactly the pre-change state. Precedence is only meaningful where both
  # sources are live.
  if st_reason 'tests/test-fx-cov-a\.sh' | grep -qF '### green-tree | cycle: 1' \
     && ! st_reason 'tests/test-fx-cov-a\.sh' | grep -qF 'green-tree-shared' \
     && st_reason 'tests/test-fx-cov-b\.sh' | grep -qF '### green-tree-shared | issue: #601'; then
    st_ok "FOLD-PRECEDENCE leg (U1, local supersedes shared)" "a suite named by both a ledger entry and a shared entry inherits citing the LEDGER entry — the cycle's own run outranks a foreign certificate"
  else
    st_fail "FOLD-PRECEDENCE leg (U1, local supersedes shared)" "expected test-fx-cov-a.sh to cite the ledger entry, got: $ST_REC"
  fi
  if st_reason 'tests/test-fx-cov-b\.sh' | grep -qF '### green-tree-shared | issue: #601'; then
    st_ok "FOLD-PRECEDENCE leg (U1, shared still contributes)" "a suite only the shared entry names still inherits from it in the same run — the precedence is an ordering, not a suppression"
  else
    st_fail "FOLD-PRECEDENCE leg (U1, shared still contributes)" "expected test-fx-cov-b.sh to cite the shared entry, got: $ST_REC"
  fi
  rm -rf "$d" "$st_ar"

  # --- HASH-LESS-SUITE leg (VERIFY step 3, U3, resolver end): a suite whose
  # `ci-subject` header cannot be read has NO computable input hash, so the
  # step-8 short-circuit cannot fire on it however the covering entry's token
  # is written — the caller resolves such a suite by the paths below it, never
  # by a certificate it cannot re-derive. `suite_input_hash` returns non-zero
  # there, mirroring select-suites.sh's own disposition: a suite whose declared
  # subject cannot be read is unjudgeable, not narrowed to nothing.
  #
  # The three header-carrying suites in the same run are the control: their
  # hashes DO compute and match, so they read `via: input-hash` while the
  # header-less one does not. Every entry head is the captured head, so no
  # selector call is made and the header-less suite cannot reach the selector
  # BLOCK its missing header would otherwise cause — the leg observes the
  # short-circuit, not the selector.
  d="$(mktemp -d)"; fixture_repo "$d"; ledger="$d/.autoflow/l.md"; : > "$ledger"
  cat > "$d/tests/test-fx-cov-nosubject.sh" <<'SH'
#!/usr/bin/env bash
# lane: standing
# budget-secs: 5
true
SH
  git -C "$d" add -A >/dev/null 2>&1
  git -C "$d" -c user.email=a@b.c -c user.name=a commit -q -m nosubject >/dev/null 2>&1
  tree="$(git -C "$d" rev-parse "HEAD^{tree}")"; head="$(git -C "$d" rev-parse HEAD)"
  fx_entry "$ledger" 1 "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" "$head" \
    "$(fx_tokens "$d" "$tree" tests/test-fx-cov-a.sh tests/test-fx-cov-b.sh tests/test-fx-cov-c.sh) tests/test-fx-cov-nosubject.sh@ffffffffffff"
  st_run "$d" "$ledger" 1 all
  if [ "$(st_via 'tests/test-fx-cov-a\.sh')" = input-hash ] \
     && [ "$(st_via 'tests/test-fx-cov-nosubject\.sh')" != input-hash ]; then
    st_ok "HASH-LESS-SUITE leg (U3, resolver end)" "a suite with no readable ci-subject never takes the input-hash short-circuit, even against a token claiming a hash, while its header-carrying siblings do"
  else
    st_fail "HASH-LESS-SUITE leg (U3, resolver end)" "expected a via: input-hash and nosubject NOT via: input-hash, got a='$(st_via 'tests/test-fx-cov-a\.sh')' nosubject='$(st_via 'tests/test-fx-cov-nosubject\.sh')': $ST_REC"
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
