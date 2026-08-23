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

ROOT=""
LEDGER=""
CYCLE=""
CANDIDATES="selection"
while [ $# -gt 0 ]; do
  case "$1" in
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
