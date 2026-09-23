#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# AUDIT security-checklist resolver (issue #281)
# =============================================================================
# The security checklist AUDIT scores against is the TARGET's: what its service
# must satisfy is its own security requirement. AutoFlow ships no checklist and
# names no item; it owns how AUDIT scores (a fresh Evaluation AI, the five
# rubric items, the PASS thresholds). A target declares where its checklist
# lives in the target-owned scaffold `.claude/autoflow.local.json`:
#
#   { "audit": { "security_checklist": "docs/security-checklist.md" } }
#
# a repository-relative path. Absent file, absent `.audit`, or an absent / null
# `.audit.security_checklist` → none declared: AUDIT scores the five rubric
# items against the change without a checklist and records that it had none.
#
# This script decides WHICH VERSION of the declared checklist a cycle's AUDIT
# reads. A target-owned checklist could be loosened by the cycle it grades —
# self-certification (CLAUDE.md > Rule Scope, principle 1). So AUDIT reads the
# checklist as of the cycle's base commit, and a change the cycle makes to it —
# the file, or the declaration that points at it — is read only on an operator
# decision recorded in the issue ledger (CLAUDE.md > Decision Ledger >
# *Security-checklist decisions*):
#
#   ## O<n> — <title> (cycle <C>, AUDIT) [checklist-decision]
#   - Checklist: <the declared path at HEAD, or none>
#   - Blob: <git rev-parse HEAD:<path>, or none>
#   - Disposition: accepted
#   - Decision: <the decision, one line>
#   - Grounds: <why, one line>
#   - Authority: operator decision
#
# An entry covers the change only when its Decision and Grounds lines are
# non-empty and its Authority is `operator decision` — the decider and the
# grounds are what makes it an operator decision (PR #297 review, Medium 1) —
# and only while its Checklist and Blob equal HEAD's, so a later edit to the
# checklist is a new change that needs its own decision.
#
# Subcommand
#   status [--base <rev>] [--ledger <path>]
#     Prints one record line, `security-checklist: <verdict> key=value ...`:
#       none-declared      no declaration at the base or at HEAD       exit 0
#       unchanged          same path and blob at the base and HEAD     exit 0
#       changed-decided    changed, covered by an accepted entry       exit 0
#       changed-undecided  changed, no covering entry                  exit 3
#     `score=` names what AUDIT reads (`<rev>:<path>`, or `none`); on exit 3 it
#     is `pending` — the orchestrator pauses for the operator before AUDIT.
#     --base  the base is `git merge-base HEAD <rev>` (default: origin/HEAD's
#             branch, then origin/main, then main).
#     --ledger  the issue ledger; without it no change is covered.
#
# Exit codes: 0 = resolved; 3 = a change needs an operator decision;
#   2 = usage, or a state the record cannot be made from (a malformed
#   declaration, a declared file not committed at that commit, an uncommitted
#   edit to the declaration or the checklist, an unresolvable base, jq absent).
# =============================================================================

set -euo pipefail

DECL_REL=".claude/autoflow.local.json"

usage() { sed -n '/^# Subcommand/,/^# Exit codes/p' "$0" | sed 's/^# \{0,1\}//' | sed '$d' >&2; exit 2; }
die() { echo "security-checklist: error: $*" >&2; exit 2; }

# decl_of <json-text> → the declared path (empty when none); exit 2 when malformed.
decl_of() {
  local out
  out="$(printf '%s' "$1" | jq -r '
    if type != "object" then "!the document is not a JSON object"
    elif (.audit // null) == null then ""
    elif (.audit | type) != "object" then "!.audit is not an object"
    elif (.audit.security_checklist // null) == null then ""
    elif (.audit.security_checklist | type) != "string"
         or (.audit.security_checklist | length) == 0
      then "!.audit.security_checklist is not a non-empty string"
    else .audit.security_checklist end' 2>/dev/null)" || die "$DECL_REL is not valid JSON"
  case "$out" in
    '!'*) die "$DECL_REL: ${out#!}" ;;
  esac
  case "$out" in
    /*|../*|*/../*|*/..|..) die "$DECL_REL: .audit.security_checklist must be a repository-relative path inside the repository: $out" ;;
  esac
  printf '%s' "$out"
}

# decl_at <rev> → the declared path at that commit (empty when none).
decl_at() {
  local json
  json="$(git show "$1:$DECL_REL" 2>/dev/null)" || return 0
  decl_of "$json"
}

# blob_at <rev> <path> → the blob id; exit 2 when the declared file is not committed there.
blob_at() {
  local b
  b="$(git rev-parse -q --verify "$1:$2" 2>/dev/null)" || die "declared checklist '$2' is not committed at $3"
  [ "$(git cat-file -t "$b")" = blob ] || die "declared checklist '$2' is not a file at $3"
  printf '%s' "$b"
}

resolve_base() {
  local r cand def
  if [ -n "$1" ]; then
    git rev-parse -q --verify "$1^{commit}" >/dev/null || die "--base '$1' does not resolve to a commit"
    git merge-base HEAD "$1" || die "no merge-base between HEAD and '$1'"
    return 0
  fi
  def="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  for cand in "$def" origin/main main; do
    [ -n "$cand" ] || continue
    if git rev-parse -q --verify "$cand^{commit}" >/dev/null; then
      r="$(git merge-base HEAD "$cand" 2>/dev/null)" && { printf '%s\n' "$r"; return 0; }
    fi
  done
  die "cannot resolve a base (no origin/HEAD, origin/main or main); pass --base <rev>"
}

# decision_id <ledger> <path|none> <blob|none> → the last accepted entry covering HEAD, or empty.
decision_id() {
  [ -n "$1" ] || return 0
  [ -r "$1" ] || die "ledger '$1' is not readable"
  awk -v want_path="$2" -v want_blob="$3" '
    function trim(s) { gsub(/`/, "", s); gsub(/^[ \t]+|[ \t\r]+$/, "", s); return s }
    function close_entry() {
      if (id != "" && path == want_path && blob == want_blob && disp == "accepted" \
          && dec != "" && grounds != "" && auth ~ /^operator decision\.?$/) hit = id
      id = ""; path = ""; blob = ""; disp = ""; dec = ""; grounds = ""; auth = ""
    }
    /^## / {
      close_entry()
      if ($0 ~ /\[checklist-decision\][ \t]*$/ && match($0, /^## O[0-9]+ /)) id = trim(substr($0, 4, RLENGTH - 4))
      next
    }
    id != "" && /^- Checklist:/   { path = trim(substr($0, length("- Checklist:") + 1)); next }
    id != "" && /^- Blob:/        { blob = trim(substr($0, length("- Blob:") + 1)); next }
    id != "" && /^- Disposition:/ { disp = trim(substr($0, length("- Disposition:") + 1)); next }
    id != "" && /^- Decision:/    { dec = trim(substr($0, length("- Decision:") + 1)); next }
    id != "" && /^- Grounds:/     { grounds = trim(substr($0, length("- Grounds:") + 1)); next }
    id != "" && /^- Authority:/   { auth = trim(substr($0, length("- Authority:") + 1)); next }
    END { close_entry(); print hit }' "$1"
}

cmd_status() {
  local base_arg="" ledger=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --base) [ $# -ge 2 ] || usage; base_arg="$2"; shift 2 ;;
      --ledger) [ $# -ge 2 ] || usage; ledger="$2"; shift 2 ;;
      *) usage ;;
    esac
  done
  command -v jq >/dev/null 2>&1 || die "jq is required"
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git work tree"
  cd "$(git rev-parse --show-toplevel)"

  local base short head_path base_path head_blob=none base_blob=none wt_path
  base="$(resolve_base "$base_arg")"
  short="$(git rev-parse --short=12 "$base")"
  head_path="$(decl_at HEAD)"
  base_path="$(decl_at "$base")"

  # AUDIT scores what is committed; an uncommitted declaration or checklist edit
  # would make the record describe a state other than the one delivered.
  wt_path=""
  [ -f "$DECL_REL" ] && wt_path="$(decl_of "$(cat "$DECL_REL")")"
  [ "$wt_path" = "$head_path" ] || die "$DECL_REL declares '${wt_path:-none}' in the work tree but '${head_path:-none}' at HEAD — commit the declaration first"

  if [ -n "$head_path" ]; then
    head_blob="$(blob_at HEAD "$head_path" HEAD)"
    git diff --quiet HEAD -- "$head_path" || die "declared checklist '$head_path' has uncommitted changes — commit them first"
  fi
  [ -n "$base_path" ] && base_blob="$(blob_at "$base" "$base_path" "the base $short")"

  if [ -z "$head_path" ] && [ -z "$base_path" ]; then
    echo "security-checklist: none-declared base=$short score=none"
    exit 0
  fi
  if [ "$head_path" = "$base_path" ] && [ "$head_blob" = "$base_blob" ]; then
    echo "security-checklist: unchanged path=$head_path base=$short blob=$head_blob score=$short:$head_path"
    exit 0
  fi

  local id hp="${head_path:-none}" score
  id="$(decision_id "$ledger" "$hp" "$head_blob")"
  if [ -n "$id" ]; then
    if [ -n "$head_path" ]; then score="HEAD:$head_path"; else score=none; fi
    echo "security-checklist: changed-decided path=$hp base=$short base_path=${base_path:-none} blob=$head_blob decision=$id score=$score"
    exit 0
  fi
  echo "security-checklist: changed-undecided path=$hp base=$short base_path=${base_path:-none} blob=$head_blob decision=none score=pending"
  exit 3
}

case "${1:-}" in
  status) shift; cmd_status "$@" ;;
  *) usage ;;
esac
