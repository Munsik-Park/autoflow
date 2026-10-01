#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# scripts/handoff/ci-test-file-jobs.sh
#
# HANDOFF — which CI job ran each test file the cycle added to the target's
# tree. Run once CI is green (scripts/handoff/confirm-ci-green.sh exit 0).
#
# It reads the GitHub Actions jobs of the pull request's head commit, fetches
# each job's log, and searches it for every file path given. The criterion is
# the path appearing in a job's log, not the file being registered in a
# workflow. It reports; whether a file no job ran is then wired into the
# target's CI is the orchestrator's judgment (docs/units/delivery.md > CI).
#
# Output, one line per file and job:
#   <file>: <job name> — <the first log line naming the file>
#   <file>: none
#
# Exit codes:
#   0   every file appears in at least one job's log
#   1   at least one file appears in no job's log
#   2   a `gh` read failed (head commit, check runs)
#   3   the head commit has no GitHub Actions job — record `no CI; local run
#       only` beside each file
#   64  usage
#
# Usage: scripts/handoff/ci-test-file-jobs.sh --pr <N> [--repo <owner/name>] <file>...

set -uo pipefail

TAG="ci-test-file-jobs"
PR=""
REPO=""
FILES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --pr) [ $# -ge 2 ] || { echo "[$TAG] --pr requires a value" >&2; exit 64; }; PR="$2"; shift 2 ;;
    --repo) [ $# -ge 2 ] || { echo "[$TAG] --repo requires a value" >&2; exit 64; }; REPO="$2"; shift 2 ;;
    -h|--help) echo "Usage: $0 --pr <N> [--repo <owner/name>] <file>..."; exit 0 ;;
    --) shift; while [ $# -gt 0 ]; do FILES+=("$1"); shift; done ;;
    -*) echo "[$TAG] unknown argument: $1" >&2; exit 64 ;;
    *) FILES+=("$1"); shift ;;
  esac
done
case "$PR" in ''|*[!0-9]*) echo "Usage: $0 --pr <N> [--repo <owner/name>] <file>..." >&2; exit 64 ;; esac
[ "${#FILES[@]}" -gt 0 ] || { echo "[$TAG] no file given — nothing to match" >&2; exit 64; }

if [ -z "$REPO" ]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" || { echo "[$TAG] cannot resolve the repository (gh repo view)" >&2; exit 2; }
fi
SHA="$(gh pr view "$PR" --repo "$REPO" --json headRefOid -q .headRefOid 2>/dev/null)" || { echo "[$TAG] cannot read the head commit of $REPO#$PR" >&2; exit 2; }
JOBS="$(gh api "repos/$REPO/commits/$SHA/check-runs?per_page=100" \
          --jq '.check_runs[] | select(.app.slug == "github-actions") | "\(.id)\t\(.name)"' 2>/dev/null)" \
  || { echo "[$TAG] cannot read the check runs of $SHA" >&2; exit 2; }

echo "pr: $REPO#$PR head $SHA"
if [ -z "$JOBS" ]; then
  echo "jobs: none — no GitHub Actions job ran on this commit"
  exit 3
fi

LOGDIR="$(mktemp -d)"
trap 'rm -rf "$LOGDIR"' EXIT
while IFS="$(printf '\t')" read -r id name; do
  [ -n "$id" ] || continue
  if gh api "repos/$REPO/actions/jobs/$id/logs" > "$LOGDIR/$id.log" 2>/dev/null; then
    printf '%s\t%s\n' "$id" "$name" >> "$LOGDIR/index"
  else
    echo "log unavailable: $name (job $id)"
  fi
done <<EOF
$JOBS
EOF

missing=0
for f in "${FILES[@]}"; do
  hit=0
  if [ -f "$LOGDIR/index" ]; then
    while IFS="$(printf '\t')" read -r id name; do
      line="$(grep -m1 -F -- "$f" "$LOGDIR/$id.log" 2>/dev/null)" || continue
      # A job log line opens with its timestamp; the report keeps what follows.
      printf '%s: %s — %s\n' "$f" "$name" "$(printf '%s' "$line" | sed -E 's/^[0-9T:.Z-]+[[:space:]]+//' | cut -c1-160)"
      hit=1
    done < "$LOGDIR/index"
  fi
  if [ "$hit" -eq 0 ]; then
    echo "$f: none"
    missing=1
  fi
done
exit "$missing"
