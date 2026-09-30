#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Cycle status — the facts PREFLIGHT is decided from (ADR-0025 D8)
# =============================================================================
# Reads and reports. It changes nothing: no fetch, no checkout, no branch or
# file is created, moved or deleted, no state file is written, and nothing is
# sent to GitHub but reads. What is done with a fact — which cycle is cleared,
# which mode the requested issue takes, where an interrupted cycle resumes —
# is the orchestrator's (docs/phases/preflight.md).
#
# Reported:
#   - the working tree: the checked-out branch and its dirty paths
#   - the default branch against its remote-tracking ref, as of the last fetch
#   - per `.autoflow/issue-*.json`: `active`, `phase`, `mode`, `cycle`; the
#     issue's dev branch (`dev/<date>-issue-<N>`) on each side; the branch's
#     pull request and its state
#   - with --issue N: for a state file of that issue, each gate's recorded
#     scores (count, min, avg), `verdict` and `remedy_class`, the artifacts on
#     disk, the ledger's last attempt markers and the last local-checks record
#     of the current cycle; without a state file, any dev branch that already
#     carries the issue's number
#
# Exit codes:
#   0   every fact was read
#   3   a fact could not be read — a `gh` lookup failed or a state file is not
#       JSON; the line that reports it says which
#   64  usage
#
# Usage: scripts/preflight/cycle-status.sh [--issue N]
# =============================================================================

set -uo pipefail

TAG="cycle-status"
ISSUE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --issue) [ $# -ge 2 ] || { echo "Usage: $0 [--issue N]" >&2; exit 64; }; ISSUE="${2#\#}"; shift 2 ;;
    -h|--help) echo "Usage: $0 [--issue N]"; exit 0 ;;
    *) echo "[$TAG] unknown argument: $1" >&2; echo "Usage: $0 [--issue N]" >&2; exit 64 ;;
  esac
done
case "$ISSUE" in
  *[!0-9]*) echo "[$TAG] --issue takes an issue number: $ISSUE" >&2; exit 64 ;;
esac

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "[$TAG] not inside a git repository" >&2; exit 64; }
cd "$ROOT" || exit 64
AF=".autoflow"
incomplete=0

# The issue-scoped dev branch is named `dev/<date>-issue-<N>`; both the local
# and the origin refs are read, so a branch that exists on one side only is
# still found.
branches_of() {
  {
    git for-each-ref --format='%(refname:lstrip=2)' "refs/heads/dev/*-issue-$1"
    git for-each-ref --format='%(refname:lstrip=3)' "refs/remotes/origin/dev/*-issue-$1"
  } | sort -u
}
side() { if git show-ref --verify --quiet "$1"; then echo yes; else echo no; fi; }

# "<number> <STATE> <url>" of the branch's pull request (an open one when there
# is one, otherwise the most recently updated), or empty.
pr_of() {
  local out
  out="$(gh pr list --head "$1" --state all --limit 30 --json number,state,url,updatedAt 2>/dev/null)" || return 1
  printf '%s' "$out" | jq -r 'sort_by(.updatedAt) | ((map(select(.state == "OPEN")) | last) // last) | if . == null then "" else "\(.number) \(.state) \(.url)" end'
}

report_branches() {  # <issue> — the dev branch on each side, and its pull request
  local n="$1" b line count
  b="$(branches_of "$n")"
  count="$(printf '%s' "$b" | grep -c . || true)"
  case "$count" in
    0) echo "  branch: none"; echo "  pr: not looked up (no dev branch to look it up by)" ;;
    1)
      echo "  branch: $b (local=$(side "refs/heads/$b") origin=$(side "refs/remotes/origin/$b"))"
      if line="$(pr_of "$b")"; then
        if [ -n "$line" ]; then echo "  pr: #${line%% *} ${line#* }"; else echo "  pr: none"; fi
      else
        echo "  pr: lookup failed"; incomplete=1
      fi ;;
    *) echo "  branch: more than one — $(printf '%s' "$b" | tr '\n' ' ')"; echo "  pr: not looked up (the branch is not unique)" ;;
  esac
}

# The result line of the last `### preflight-local-checks | cycle: <C>` record.
last_local_checks() {
  [ -f "$1" ] || { echo "none"; return; }
  awk -v c="$2" '
    $0 == "### preflight-local-checks | cycle: " c { want = 1; next }
    want && /^- result: / { sub(/^- result: (PREFLIGHT local checks: )?/, ""); last = $0; want = 0 }
    END { print (last == "" ? "none" : last) }' "$1"
}

report_detail() {  # <issue> <cycle> — what a resume is judged from
  local n="$1" led="$AF/issue-$1-ledger.md" f m
  echo "  gates:"
  jq -r '
    def num: if type == "object" then .score else . end;
    (.phases // {}) | to_entries[] |
    "    \(.key): " +
    ( (.value.scores // {}) as $s
      | if ($s | length) == 0 then "no scores"
        else ([$s[] | num]) as $v | "scores=\($v | length) min=\($v | min) avg=\(($v | add) / ($v | length) * 100 | round / 100)" end )
    + (if .value.verdict != null and .value.verdict != "" then " verdict=\"\(.value.verdict)\"" else "" end)
    + (if .value.remedy_class != null then " remedy_class=\(.value.remedy_class)" else "" end)
  ' "$AF/issue-$n.json" 2>/dev/null
  echo "  artifacts:"
  for f in "$AF"/issue-"$n"-*; do
    [ -e "$f" ] || continue
    case "${f##*/}" in issue-"$n"-c[0-9]*-*) continue ;; esac
    echo "    ${f##*/}"
  done
  if [ -f "$led" ]; then
    echo "  ledger markers (last of each):"
    for m in gate-autofix rebuttal review-autofix reentry-decision; do
      grep -n -E "^## .*\[$m\][[:space:]]*$" "$led" | tail -1 | sed 's/^/    /'
    done
    echo "  last local-checks record (cycle $2): $(last_local_checks "$led" "$2")"
  else
    echo "  ledger: none"
  fi
}

dirty="$(git status --porcelain)"
echo "working tree: branch $(git rev-parse --abbrev-ref HEAD), $(printf '%s' "$dirty" | grep -c . || true) dirty path(s)"
[ -n "$dirty" ] && printf '%s\n' "$dirty" | sed 's/^/  /'

DEFAULT="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)" || DEFAULT="origin/main"
DEFAULT="${DEFAULT#origin/}"
if git show-ref --verify --quiet "refs/heads/$DEFAULT" && git show-ref --verify --quiet "refs/remotes/origin/$DEFAULT"; then
  echo "default branch: $DEFAULT at $(git rev-parse --short "$DEFAULT"), origin/$DEFAULT at $(git rev-parse --short "origin/$DEFAULT") as of the last fetch — ahead $(git rev-list --count "origin/$DEFAULT..$DEFAULT"), behind $(git rev-list --count "$DEFAULT..origin/$DEFAULT")"
else
  echo "default branch: $DEFAULT — no local branch or no remote-tracking ref"
fi

own_seen=0
found=0
for f in "$AF"/issue-*.json; do
  [ -f "$f" ] || continue
  n="${f##*/issue-}"; n="${n%.json}"
  case "$n" in ''|*[!0-9]*) continue ;; esac
  found=1
  if ! jq -e . "$f" >/dev/null 2>&1; then
    echo "issue #$n: state file unreadable ($f)"; incomplete=1
    [ "$n" = "$ISSUE" ] && own_seen=1
    continue
  fi
  cycle="$(jq -r '.cycle // 1' "$f")"
  echo "issue #$n: active=$(jq -r '.active // false' "$f") phase=$(jq -r '.phase // "unset"' "$f") mode=$(jq -r '.mode // "unset"' "$f") cycle=$cycle"
  report_branches "$n"
  if [ "$n" = "$ISSUE" ]; then own_seen=1; report_detail "$n" "$cycle"; fi
done
[ "$found" -eq 0 ] && echo "state files: none"

if [ -n "$ISSUE" ] && [ "$own_seen" -eq 0 ]; then
  echo "issue #$ISSUE: no state file"
  report_branches "$ISSUE"
fi

[ "$incomplete" -eq 0 ] || exit 3
exit 0
