#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# scripts/review/scope-bounded.sh — mechanical scope judgment for a review-response cycle (issue #135)
#
# A review-response cycle (re-entered on a Medium+ reviewer finding) is `scope-bounded` when the
# judgment below holds. The judgment is a set relation, never an agent's "this is small":
#
#   triage   every Medium+ finding names a file, and each file is in the diff of the PR the
#            finding belongs to (issue #280: the PR whose repository owns the code, which is
#            not always the PR whose review raised it);
#   entry    every reviewed PR whose findings file carries a Medium+ verdict judged `true` —
#            the review-response cycle is one per issue, so the heavier judgment wins;
#   fix      the fix adds no new file (a new script / workflow / hook / test file is a new
#            mechanism and leaves the bounded path).
#
# Subcommands
#   triage --findings <file> (--pr <N> [--repo <owner/name>] | --diff-files <file>)
#          [--owner-diff <owner/name>#<N>=<file>]...
#         Judges one reviewed PR's findings file. A Medium+ row with no owner cell, or whose
#         owner is the file's own `pr:` line, is compared against the reviewed PR's diff
#         (`gh pr diff <N> [--repo]`, or --diff-files); a row owned by another PR against that
#         PR's diff (--owner-diff, else `gh pr diff <N> --repo <owner/name>`). A --pr / --repo
#         that disagrees with the file's `pr:` line is a usage error. Prints three lines for
#         the orchestrator to append to the findings file:
#           scope-bounded: true|false
#           scope-bounded-finding-files: <space-separated; another owner's as <owner/name>#<N>:<path>>
#           scope-bounded-grounds: <reason>
#         Exit 0 when bounded, 1 when not, 2 on usage / unreadable input / unreadable diff.
#   entry --issue <N> [--dir <dir>]
#         Combines the per-PR findings files <dir>/issue-<N>-review-findings-*.md (dir default
#         .autoflow; a pre-#280 issue-<N>-review-findings.md only when none exists) for PREFLIGHT's
#         Scope-bounded entry. Bounded only when at least one file's max_severity is Medium+ and
#         every such file carries `scope-bounded: true`; a `false`, a Medium+ file with no line,
#         or a file whose max_severity line is missing, repeated or unparseable is the full path.
#         Prints
#           scope-bounded: true|false
#           scope-bounded-grounds: <reason>
#         Exit 0 when bounded, 1 when not, 2 on usage.
#   check-fix --base <rev> --head <rev>
#         Re-evaluates the fix condition after GREEN. Prints
#           scope-bounded-fix: true|false
#           scope-bounded-fix-grounds: <reason>
#         Exit 0 when the bounded path holds, 1 when it must be left, 2 on usage.
#
# Findings-file grammar (docs/autoflow-guide.md > HANDOFF step 6.5): a `pr: <owner/name>#<N>`
# line naming the reviewed PR, one `max_severity: <None|Low|Medium|High|Critical>` line (`=` and
# whitespace separators tolerated), and a markdown table whose first cell is the severity, whose
# second cell is `path:line` (or `path`), and one of whose later cells is the owner
# `<owner/name>#<N>`. Rows below the first "superseded" / "historical" heading are ignored.

set -euo pipefail

usage() { sed -n '/^# Subcommands/,/^# Findings-file/p' "$0" | sed 's/^# \{0,1\}//' | sed '$d' >&2; exit 2; }
die() { echo "scope-bounded: error: $*" >&2; exit 2; }

REF_RE='^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#[0-9]+$'

# finding_rows <findings.md> → one "<owner>\t<path>" line per Medium+ row; the owner is empty when
# the row has no `owner/name#N` cell, and the path is "<nofile>" for a Medium+ row with no
# parseable path so the caller can fail closed.
finding_rows() {
  awk '
    /^#+ .*([Ss]uperseded|[Hh]istorical)/ { stop = 1 }
    stop { next }
    /^\|/ {
      n = split($0, c, "|")
      sev = c[2]; gsub(/^[ \t]+|[ \t]+$/, "", sev)
      if (sev != "Medium" && sev != "High" && sev != "Critical") next
      loc = c[3]; gsub(/`/, "", loc); gsub(/^[ \t]+|[ \t]+$/, "", loc)
      sub(/:[0-9].*$/, "", loc); sub(/[ \t].*$/, "", loc)
      if (loc == "" || loc == "—" || loc == "-") loc = "<nofile>"
      owner = ""
      for (i = 4; i < n; i++) {
        v = c[i]; gsub(/`/, "", v); gsub(/^[ \t]+|[ \t]+$/, "", v)
        if (v ~ /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+#[0-9]+$/) { owner = v; break }
      }
      print owner "\t" loc
    }' "$1" | sort -u
}

# file_pr <findings.md> → the value of the first `pr:` line (empty when absent).
file_pr() {
  awk '/^[ \t]*pr:/ { v = $0; sub(/^[ \t]*pr:[ \t]*/, "", v); gsub(/`/, "", v); sub(/[ \t]+$/, "", v); print v; exit }' "$1"
}

# pr_diff <owner/name#N> → the PR's changed file names, sorted.
pr_diff() {
  local out
  out=$(gh pr diff "${1##*#}" --repo "${1%#*}" --name-only) || die "could not read the diff of $1"
  printf '%s\n' "$out" | sort -u
}

cmd_triage() {
  local findings="" pr="" repo="" difffile="" owner_diffs=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --findings) findings="${2:-}"; shift 2 ;;
      --pr) pr="${2:-}"; shift 2 ;;
      --repo) repo="${2:-}"; shift 2 ;;
      --diff-files) difffile="${2:-}"; shift 2 ;;
      --owner-diff) owner_diffs="${owner_diffs}${2:-}"$'\n'; shift 2 ;;
      *) usage ;;
    esac
  done
  [ -n "$findings" ] && [ -r "$findings" ] || usage
  [ -n "$pr" ] || [ -n "$difffile" ] || usage
  [ -z "$difffile" ] || [ -r "$difffile" ] || usage
  [ -z "$repo" ] || [[ "$repo#0" =~ $REF_RE ]] || usage

  # The reviewed PR: the file's own `pr:` line, which --pr / --repo must not contradict — a
  # findings file judged against another PR's diff is the defect issue #280 removes.
  local own_ref
  own_ref=$(file_pr "$findings")
  if [ -n "$own_ref" ]; then
    [[ "$own_ref" =~ $REF_RE ]] || die "$findings: pr: line is not <owner/name>#<N>: $own_ref"
    [ -z "$pr" ] || [ "${own_ref##*#}" = "$pr" ] || die "$findings is for $own_ref, --pr names #$pr"
    [ -z "$repo" ] || [ "${own_ref%#*}" = "$repo" ] || die "$findings is for $own_ref, --repo names $repo"
  elif [ -n "$repo" ] && [ -n "$pr" ]; then
    own_ref="$repo#$pr"
  fi

  local rows
  rows=$(finding_rows "$findings" | awk -F'\t' -v own="$own_ref" '{ print (($1 == own) ? "" : $1) "\t" $2 }' | sort -u)
  local files_line
  files_line=$(printf '%s\n' "$rows" | awk -F'\t' 'NF { printf "%s%s", sep, (($1 == "") ? $2 : $1 ":" $2); sep = " " }')
  if [ -z "$rows" ]; then
    printf 'scope-bounded: false\nscope-bounded-finding-files:\nscope-bounded-grounds: no Medium+ finding row — nothing to bound\n'
    return 1
  fi
  if printf '%s\n' "$rows" | cut -f2 | grep -qx '<nofile>'; then
    printf 'scope-bounded: false\nscope-bounded-finding-files: %s\nscope-bounded-grounds: a Medium+ finding names no file — set relation not evaluable, full path\n' "$files_line"
    return 1
  fi

  # Compare each owner's rows against that owner's diff; the empty owner is the reviewed PR.
  local outside="" sizes="" owner diff_set paths out mapped
  while IFS= read -r owner; do
    if [ -z "$owner" ]; then
      if [ -n "$difffile" ]; then
        diff_set=$(sort -u "$difffile")
      elif [ -n "$repo" ]; then
        diff_set=$(gh pr diff "$pr" --repo "$repo" --name-only) || die "could not read the diff of $repo#$pr"
      else
        diff_set=$(gh pr diff "$pr" --name-only) || die "could not read the diff of #$pr"
      fi
      diff_set=$(printf '%s\n' "$diff_set" | sort -u)
    else
      mapped=$(printf '%s' "$owner_diffs" | awk -v r="$owner" 'index($0, r "=") == 1 { print substr($0, length(r) + 2); exit }')
      if [ -n "$mapped" ]; then
        [ -r "$mapped" ] || die "--owner-diff file unreadable: $mapped"
        diff_set=$(sort -u "$mapped")
      else
        diff_set=$(pr_diff "$owner")
      fi
    fi
    paths=$(printf '%s\n' "$rows" | awk -F'\t' -v o="$owner" '$1 == o { print $2 }' | sort -u)
    out=$(comm -23 <(printf '%s\n' "$paths") <(printf '%s\n' "$diff_set") | awk -v o="$owner" 'NF { printf "%s%s", sep, ((o == "") ? $0 : o ":" $0); sep = " " }')
    [ -z "$out" ] || outside="${outside:+$outside }$out"
    sizes="${sizes:+$sizes; }${owner:-reviewed PR} $(printf '%s\n' "$diff_set" | grep -c . || true) files"
  done <<< "$(printf '%s\n' "$rows" | cut -f1 | sort -u)"

  if [ -n "$outside" ]; then
    printf 'scope-bounded: false\nscope-bounded-finding-files: %s\nscope-bounded-grounds: outside the owning PR diff: %s\n' "$files_line" "$outside"
    return 1
  fi
  printf 'scope-bounded: true\nscope-bounded-finding-files: %s\nscope-bounded-grounds: finding files ⊆ owning PR diff files (%s in diff)\n' "$files_line" "$sizes"
  return 0
}

cmd_entry() {
  local issue="" dir=".autoflow"
  while [ $# -gt 0 ]; do
    case "$1" in
      --issue) issue="${2:-}"; shift 2 ;;
      --dir) dir="${2:-}"; shift 2 ;;
      *) usage ;;
    esac
  done
  [[ "$issue" =~ ^[0-9]+$ ]] || usage
  [ -d "$dir" ] || usage

  # A pre-#280 single file is read only when no per-PR file exists: beside per-PR files it is
  # a stale verdict from before the switch, and would decide the path for reviews that no
  # longer hold.
  local files
  files=$(find "$dir" -maxdepth 1 -type f -name "issue-${issue}-review-findings-*.md" | LC_ALL=C sort)
  [ -n "$files" ] || files=$(find "$dir" -maxdepth 1 -type f -name "issue-${issue}-review-findings.md")
  if [ -z "$files" ]; then
    printf 'scope-bounded: false\nscope-bounded-grounds: no findings file for issue #%s — full path\n' "$issue"
    return 1
  fi

  local f name sev count verdict notes="" defect=0 bounded=0 medium=0
  while IFS= read -r f; do
    name=${f##*/}
    # max_severity: count every line that declares the key, whatever its value, so a malformed
    # second declaration is a repeat rather than invisible; then parse the one line — colon
    # canonical, `=` and whitespace tolerated.
    count=$(grep -cE '^[[:space:]]*max_severity([[:space:]:=]|$)' "$f" || true)
    if [ "$count" -ne 1 ]; then
      notes="${notes:+$notes; }$name max_severity lines: $count"; defect=1; continue
    fi
    sev=$(sed -nE 's/^[[:space:]]*max_severity([[:space:]]*[:=][[:space:]]*|[[:space:]]+)([A-Za-z]+)[[:space:]]*$/\2/p' "$f")
    case "$sev" in
      None|Low) continue ;;
      Medium|High|Critical) medium=$((medium + 1)) ;;
      *) notes="${notes:+$notes; }$name max_severity unparseable: $(grep -m 1 -E '^[[:space:]]*max_severity' "$f" | sed -E 's/^[[:space:]]+//')"; defect=1; continue ;;
    esac
    verdict=$(sed -nE 's/^scope-bounded:[[:space:]]*(true|false)[[:space:]]*$/\1/p' "$f" | sort -u | tr '\n' ' ')
    case "$verdict" in
      "true ") bounded=$((bounded + 1)); notes="${notes:+$notes; }$name $sev bounded" ;;
      "") notes="${notes:+$notes; }$name $sev with no scope-bounded line"; defect=1 ;;
      *) notes="${notes:+$notes; }$name $sev not bounded"; defect=1 ;;
    esac
  done <<< "$files"

  if [ "$medium" -eq 0 ] && [ "$defect" -eq 0 ]; then
    printf 'scope-bounded: false\nscope-bounded-grounds: no Medium+ findings file — nothing to bound\n'
    return 1
  fi
  if [ "$defect" -ne 0 ] || [ "$bounded" -ne "$medium" ]; then
    printf 'scope-bounded: false\nscope-bounded-grounds: %s\n' "$notes"
    return 1
  fi
  printf 'scope-bounded: true\nscope-bounded-grounds: %s\n' "$notes"
  return 0
}

cmd_check_fix() {
  local base="" head=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --base) base="${2:-}"; shift 2 ;;
      --head) head="${2:-}"; shift 2 ;;
      *) usage ;;
    esac
  done
  [ -n "$base" ] && [ -n "$head" ] || usage
  local added
  added=$(git diff --diff-filter=A --name-only "$base" "$head" | tr '\n' ' ' | sed 's/ $//')
  if [ -n "$added" ]; then
    printf 'scope-bounded-fix: false\nscope-bounded-fix-grounds: the fix adds new files (new mechanism): %s\n' "$added"
    return 1
  fi
  printf 'scope-bounded-fix: true\nscope-bounded-fix-grounds: no file added between %s and %s\n' "$base" "$head"
  return 0
}

case "${1:-}" in
  triage) shift; cmd_triage "$@" ;;
  entry) shift; cmd_entry "$@" ;;
  check-fix) shift; cmd_check_fix "$@" ;;
  *) usage ;;
esac
