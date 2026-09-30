#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# scripts/state/set-phase.sh
#
# Moves an issue's state file (`.autoflow/issue-<N>.json`) to a lifecycle
# marker. `active` follows the marker — the two are never set apart:
#
#   in-progress, review-triage      → active: true
#   awaiting-user                   → active: false  (a pause for the operator)
#   awaiting-external-review        → active: false  (HANDOFF's end)
#
# `awaiting-external-review` is the hand-off. HANDOFF names every pull request
# the cycle opened with `--pr`, and the transition is refused while one of them
# still carries `blocked-by-review`; a hand-off that opened no pull request (a
# review-response the structure form found already satisfied) names none. On
# success it also removes the issue's `status:in-progress` label. Nothing else
# in the state file changes.
#
# Exit codes:
#   0   the state file carries the marker
#   1   refused — a named pull request still carries `blocked-by-review`; the
#       state file is unchanged
#   2   the state file is absent or unreadable
#   3   a `gh` read failed; the state file is unchanged
#   64  usage
#
# Usage: scripts/state/set-phase.sh --issue <N> --phase <marker> [--pr <[owner/name#]P>]...

set -uo pipefail

TAG="set-phase"
ISSUE=""
PHASE=""
PRS=()
usage() { echo "Usage: $0 --issue <N> --phase <in-progress|review-triage|awaiting-user|awaiting-external-review> [--pr <[owner/name#]P>]..."; }
while [ $# -gt 0 ]; do
  case "$1" in
    --issue) [ $# -ge 2 ] || { usage >&2; exit 64; }; ISSUE="${2#\#}"; shift 2 ;;
    --phase) [ $# -ge 2 ] || { usage >&2; exit 64; }; PHASE="$2"; shift 2 ;;
    --pr) [ $# -ge 2 ] || { usage >&2; exit 64; }; PRS+=("$2"); shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[$TAG] unknown argument: $1" >&2; usage >&2; exit 64 ;;
  esac
done
case "$ISSUE" in ''|*[!0-9]*) usage >&2; exit 64 ;; esac
case "$PHASE" in
  in-progress|review-triage) ACTIVE=true ;;
  awaiting-user|awaiting-external-review) ACTIVE=false ;;
  *) usage >&2; exit 64 ;;
esac
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "[$TAG] not inside a git repository" >&2; exit 64; }
cd "$ROOT" || exit 64
STATE=".autoflow/issue-$ISSUE.json"
jq -e . "$STATE" >/dev/null 2>&1 || { echo "[$TAG] $STATE is absent or unreadable"; exit 2; }

if [ "$PHASE" = "awaiting-external-review" ] && [ "${#PRS[@]}" -gt 0 ]; then
  for pr in "${PRS[@]}"; do
    num="${pr##*#}"
    repo_args=()
    case "$pr" in *"#"*) repo_args=(--repo "${pr%%#*}") ;; esac
    case "$num" in ''|*[!0-9]*) echo "[$TAG] --pr takes <P> or <owner/name>#<P>: $pr" >&2; exit 64 ;; esac
    labels="$(gh pr view "$num" ${repo_args[@]+"${repo_args[@]}"} --json labels -q '.labels[].name' 2>/dev/null)" \
      || { echo "[$TAG] cannot read the labels of pull request $pr"; exit 3; }
    if printf '%s\n' "$labels" | grep -qx 'blocked-by-review'; then
      echo "refused: pull request $pr still carries blocked-by-review — the review is not clean"
      exit 1
    fi
    echo "pr $pr: blocked-by-review absent"
  done
fi

tmp="$(mktemp ".autoflow/.issue-$ISSUE.json.XXXXXX")"
if jq --argjson a "$ACTIVE" --arg p "$PHASE" '.active = $a | .phase = $p' "$STATE" > "$tmp"; then
  mv "$tmp" "$STATE"
else
  rm -f "$tmp"
  echo "[$TAG] cannot rewrite $STATE"
  exit 2
fi
echo "state: $STATE -> active=$ACTIVE phase=$PHASE"

if [ "$PHASE" = "awaiting-external-review" ]; then
  if gh issue edit "$ISSUE" --remove-label "status:in-progress" >/dev/null 2>&1; then
    echo "label: status:in-progress removed from #$ISSUE"
  else
    echo "label: status:in-progress not removed from #$ISSUE (absent, or the label does not exist)"
  fi
fi
exit 0
