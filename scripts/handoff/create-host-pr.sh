#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# scripts/handoff/create-host-pr.sh
#
# HANDOFF step 4 — host PR creation entrypoint.
# Always creates the host PR as `--draft` and applies the `blocked-by-review`
# gate label to EVERY host PR (regardless of `--no-subrepo-dep`); that label is
# cleared by the Codex review in step 6 only when the review finds zero
# Critical/High/Medium findings. Additionally applies the `blocked-by-subrepo`
# label by default; `--no-subrepo-dep` omits ONLY that label for host-only PRs.
# Merge-order clearance is the operator's `blocked-by-subrepo` label removal,
# performed after the operator confirms the sub-repo merge + pointer reconcile
# are complete — docs/external-review-sequencing.md.
#
# Promotion from draft -> ready is performed manually by the external reviewer.
# See docs/external-review-sequencing.md.
#
# Usage:
#   scripts/handoff/create-host-pr.sh --issue N --title T --body-file PATH [--no-subrepo-dep]

set -euo pipefail

ISSUE=""
TITLE=""
BODY_FILE=""
NO_SUBREPO_DEP="false"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --issue) ISSUE="${2:-}"; shift 2 ;;
    --title) TITLE="${2:-}"; shift 2 ;;
    --body-file) BODY_FILE="${2:-}"; shift 2 ;;
    --no-subrepo-dep) NO_SUBREPO_DEP="true"; shift 1 ;;
    *) echo "unknown arg: $1" >&2; exit 64 ;;
  esac
done

if [ -z "$ISSUE" ] || [ -z "$TITLE" ] || [ -z "$BODY_FILE" ]; then
  echo "usage: $0 --issue N --title T --body-file PATH [--no-subrepo-dep]" >&2
  exit 64
fi

if [ ! -f "$BODY_FILE" ]; then
  echo "body file not found: $BODY_FILE" >&2
  exit 66
fi

args=(--draft --title "$TITLE" --body-file "$BODY_FILE" --label "blocked-by-review")
if [ "$NO_SUBREPO_DEP" != "true" ]; then
  args+=(--label "blocked-by-subrepo")
fi

gh pr create "${args[@]}"
