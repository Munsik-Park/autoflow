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
# the file, or the declaration that points at it — is read only on a decision
# recorded in the issue ledger (docs/decision-ledger.md > *Security-checklist
# decisions*): the advisor's first judgment, or the operator's override
# (ADR-0025 D7):
#
#   ## A<n> — <title> (cycle <C>, AUDIT) [checklist-decision]   (advisor)
#   ## O<n> — <title> (cycle <C>, AUDIT) [checklist-decision]   (operator)
#   - Checklist: <the declared path at HEAD, or none>
#   - Blob: <git rev-parse HEAD:<path>, or none>
#   - Disposition: accepted | rejected
#   - Decision: <the decision, one line>
#   - Grounds: <why, one line>
#   - Authority: advisor decision | operator decision
#   - Supersedes: <id>  |  Overrides: A<n>   (only on an entry that replaces one)
#
# An entry counts only when its Decision and Grounds lines are non-empty, its
# Disposition is `accepted` or `rejected`, and its Authority matches its
# namespace — `advisor decision` on an `A<n>` entry, `operator decision` on an
# `O<n>` entry; the decider and the grounds are what make it a decision (PR #297
# review, Medium 1), and the gate hook admits an `A<n>` entry only from the
# advisor and an `O<n>` entry only from the main session — and only while its
# Checklist and Blob equal HEAD's, so a later edit to the checklist is a new
# change that needs its own decision. A decision changes only by a later entry
# that names the one it replaces (`- Supersedes: <id>`, or an operator's
# `- Overrides: A<n>`); an advisor entry cannot replace an operator entry.
# Standing entries that disagree are a conflict: reported, never settled by
# recency, and left undecided until an entry resolves it. Any line starting
# with `#` ends an entry, and an entry that carries one of its fields twice is
# void: it decides nothing and is reported as `invalid=<ids>` on an undecided
# record, since only an edit or an append without a heading can produce it.
#
# Subcommand
#   status [--base <rev>] [--ledger <path>]
#     Prints one record line, `security-checklist: <verdict> key=value ...`:
#       none-declared      no declaration at the base or at HEAD       exit 0
#       unchanged          same path and blob at the base and HEAD     exit 0
#       changed-decided    changed, covered by an accepted entry       exit 0
#       changed-undecided  changed, no covering entry, standing        exit 3
#                          entries that disagree (`conflict=<ids>`), or
#                          an entry with a repeated field (`invalid=<ids>`)
#     `score=` names what AUDIT reads (`<rev>:<path>`, or `none`); on exit 3 it
#     is `pending` — the orchestrator spawns the advisor before AUDIT.
#     --base  the base is `git merge-base HEAD <rev>` (default: origin/HEAD's
#             branch, then origin/main, then main).
#     --ledger  the issue ledger; without it no change is covered.
#
# Exit codes: 0 = resolved; 3 = a change needs a decision (the advisor's first);
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

# decision_id <ledger> <path|none> <blob|none> → the entry covering HEAD's
# checklist, `INVALID:<id>,…` when an entry for HEAD's checklist repeats a
# field, `CONFLICT:<id>,<id>…` when the standing entries disagree, or empty.
# An entry stands unless a LATER counted entry names it on a `- Supersedes:` or
# `- Overrides:` line; an advisor entry never displaces an operator entry. The
# standing entries decide only when they agree: all `accepted` → the last of
# them covers the change; all `rejected` → nothing covers it; both → a conflict,
# reported and left undecided (the ledger's supersession rule — nothing is
# settled by recency).
decision_id() {
  [ -n "$1" ] || return 0
  [ -r "$1" ] || die "ledger '$1' is not readable"
  LC_ALL=C awk -v want_path="$2" -v want_blob="$3" '
    function trim(s) { gsub(/`/, "", s); gsub(/^[ \t]+|[ \t\r]+$/, "", s); return s }
    function field(name, v) {
      if (seen[name]++) dup = 1
      if (name == "Checklist" && v == want_path) pathok = 1
      if (name == "Blob" && v == want_blob) blobok = 1
      val[name] = v
    }
    function close_entry(   ok) {
      if (id != "" && pathok && blobok && dup) { bad = bad (bad == "" ? "" : ",") id }
      ok = (id != "" && !dup && pathok && blobok \
            && (val["Disposition"] == "accepted" || val["Disposition"] == "rejected") \
            && val["Decision"] != "" && val["Grounds"] != "" \
            && ((id ~ /^O/ && val["Authority"] ~ /^operator decision\.?$/) || (id ~ /^A/ && val["Authority"] ~ /^advisor decision\.?$/)))
      if (ok) { n++; eid[n] = id; edisp[n] = val["Disposition"]; erepl[n] = val["Supersedes"] " " val["Overrides"] }
      id = ""; dup = 0; pathok = 0; blobok = 0
      split("", seen); split("", val)
    }
    { sub(/\r$/, "") }
    /^#/ {
      close_entry()
      if ($0 ~ /^## / && $0 ~ /\[checklist-decision\][ \t]*$/ && match($0, /^## [OA][0-9]+ /)) id = trim(substr($0, 4, RLENGTH - 4))
      next
    }
    id != "" && match($0, /^- (Checklist|Blob|Disposition|Decision|Grounds|Authority|Supersedes|Overrides):/) {
      name = substr($0, 3, RLENGTH - 3)
      field(name, trim(substr($0, RLENGTH + 1)))
      next
    }
    END {
      close_entry()
      if (bad != "") { print "INVALID:" bad; exit }
      for (i = 1; i <= n; i++) {
        m = split(erepl[i], t, /[ ,;`]+/)
        for (k = 1; k <= m; k++) {
          if (t[k] == "") continue
          for (j = 1; j < i; j++)
            if (eid[j] == t[k] && !(eid[i] ~ /^A/ && eid[j] ~ /^O/)) gone[j] = 1
        }
      }
      acc = 0; rej = 0; last = ""; ids = ""
      for (i = 1; i <= n; i++) {
        if (gone[i]) continue
        ids = ids (ids == "" ? "" : ",") eid[i]
        if (edisp[i] == "accepted") { acc = 1; last = eid[i] } else rej = 1
      }
      if (acc && rej) print "CONFLICT:" ids
      else if (acc) print last
    }' "$1"
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
  case "$id" in
    INVALID:*)
      echo "security-checklist: changed-undecided path=$hp base=$short base_path=${base_path:-none} blob=$head_blob decision=none invalid=${id#INVALID:} score=pending"
      exit 3
      ;;
    CONFLICT:*)
      echo "security-checklist: changed-undecided path=$hp base=$short base_path=${base_path:-none} blob=$head_blob decision=none conflict=${id#CONFLICT:} score=pending"
      exit 3
      ;;
  esac
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
