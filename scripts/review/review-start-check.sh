#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# scripts/review/review-start-check.sh
#
# HANDOFF — did the reviewer run for one pull request begin? Run right after
# `scripts/review/codex-review-pr.sh` is launched in the background, once per
# reviewed PR. It waits at most the window for a signal scoped to that PR and
# reports the first one it finds:
#
#   completed  the wrapper's output (--log) already carries its completion
#              marker `[review] <backend> completed for PR #<N> (exit=<K>)`
#   process    a reviewer process whose prompt names `pull request #<N>` is
#              running (both backends pass the prompt as an argument)
#   rollout    codex only: a session rollout written within the window's reach
#              whose prompt names `pull request #<N>`
#
# With --repo, the process and rollout signals also require the prompt's
# `--repo <owner/name>` clause, which tells a sub-repo PR from a host PR of the
# same number.
#
# Exit codes:
#   0   started, or already completed with exit 0
#   1   no signal within the window — launch the review again once; a second
#       miss goes to the operator
#   3   the wrapper completed with a non-zero exit — the review run itself
#       failed
#   64  usage
#
# Usage: scripts/review/review-start-check.sh --pr <N> [--repo <owner/name>]
#                                             [--log <wrapper output>] [--window <secs>]

set -uo pipefail

TAG="review-start-check"
PR=""
REPO=""
LOGFILE=""
WINDOW="${REVIEW_START_WINDOW_SECS:-30}"
while [ $# -gt 0 ]; do
  case "$1" in
    --pr) [ $# -ge 2 ] || { echo "[$TAG] --pr requires a value" >&2; exit 64; }; PR="$2"; shift 2 ;;
    --repo) [ $# -ge 2 ] || { echo "[$TAG] --repo requires a value" >&2; exit 64; }; REPO="$2"; shift 2 ;;
    --log) [ $# -ge 2 ] || { echo "[$TAG] --log requires a value" >&2; exit 64; }; LOGFILE="$2"; shift 2 ;;
    --window) [ $# -ge 2 ] || { echo "[$TAG] --window requires a value" >&2; exit 64; }; WINDOW="$2"; shift 2 ;;
    -h|--help) echo "Usage: $0 --pr <N> [--repo <owner/name>] [--log <wrapper output>] [--window <secs>]"; exit 0 ;;
    *) echo "[$TAG] unknown argument: $1" >&2; exit 64 ;;
  esac
done
case "$PR" in ''|*[!0-9]*) echo "Usage: $0 --pr <N> [--repo <owner/name>] [--log <wrapper output>] [--window <secs>]" >&2; exit 64 ;; esac
case "$WINDOW" in ''|*[!0-9]*) echo "[$TAG] --window takes seconds: $WINDOW" >&2; exit 64 ;; esac

# The wrapper's prompt opens `Review pull request #<N>. `; the trailing period
# keeps #5 from matching #57.
PROMPT_RE="Review pull request #${PR}\\. "
[ -n "$REPO" ] && PROMPT_RE="${PROMPT_RE}.*--repo ${REPO}'"
SESSIONS="${CODEX_HOME:-$HOME/.codex}/sessions"
# A rollout older than the window plus a minute belongs to an earlier round.
REACH_MIN=$(( WINDOW / 60 + 2 ))

elapsed=0
while :; do
  if [ -n "$LOGFILE" ] && [ -f "$LOGFILE" ]; then
    done_line="$(grep -E "^\[review\] [a-z]+ completed for PR #${PR} \(exit=[0-9]+\)" "$LOGFILE" | tail -1)"
    if [ -n "$done_line" ]; then
      echo "completed: $done_line"
      case "$done_line" in *"(exit=0)"*) exit 0 ;; *) exit 3 ;; esac
    fi
  fi
  pid="$(pgrep -f -- "$PROMPT_RE" 2>/dev/null | head -1)"
  if [ -n "$pid" ]; then
    echo "started: process $pid (prompt names pull request #$PR${REPO:+ in $REPO})"
    exit 0
  fi
  if [ -d "$SESSIONS" ]; then
    rollout="$(find "$SESSIONS" -name 'rollout-*.jsonl' -mmin "-$REACH_MIN" -exec grep -l -E -- "$PROMPT_RE" {} + 2>/dev/null | head -1)"
    if [ -n "$rollout" ]; then
      echo "started: rollout $rollout (prompt names pull request #$PR${REPO:+ in $REPO})"
      exit 0
    fi
  fi
  [ "$elapsed" -ge "$WINDOW" ] && break
  sleep 2
  elapsed=$((elapsed + 2))
done
echo "not started: no process, rollout or completion marker for pull request #$PR${REPO:+ in $REPO} within ${WINDOW}s"
exit 1
