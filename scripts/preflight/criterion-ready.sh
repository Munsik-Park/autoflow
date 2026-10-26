#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
# =============================================================================
# Criterion readiness — the sha256 of an issue body, the value a criterion
# review record names the body by (issues #430, #465; docs/criterion-review.md)
# =============================================================================
# Reads and reports (ADR-0025 D8). It changes nothing: no ledger entry, no
# file, no issue edit. Whether an issue's acceptance criteria are right is not
# judged here — that is the criterion review's (docs/criterion-review.md).
#
# Subcommand:
#   hash --issue N   print the sha256 of the issue body as GitHub holds it
#                    now — the value the review record's `Issue body sha256:`
#                    line records
#
# Exit codes:
#   0   hash printed
#   3   a fact could not be read — the issue body lookup failed
#   64  usage
#
# Usage: scripts/preflight/criterion-ready.sh hash --issue N
# =============================================================================

set -uo pipefail

TAG="criterion-ready"
usage() { echo "Usage: $0 hash --issue N" >&2; exit 64; }

SUB="${1:-}"
[ "$#" -gt 0 ] && shift
case "$SUB" in hash) ;; -h|--help) echo "Usage: $0 hash --issue N"; exit 0 ;; *) usage ;; esac
ISSUE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --issue) [ $# -ge 2 ] || usage; ISSUE="${2#\#}"; shift 2 ;;
    *) echo "[$TAG] unknown argument: $1" >&2; usage ;;
  esac
done
case "$ISSUE" in ''|*[!0-9]*) echo "[$TAG] --issue takes an issue number: '$ISSUE'" >&2; usage ;; esac

# The issue is read from the repository of the working directory (gh).
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "[$TAG] not inside a git repository" >&2; exit 64; }
cd "$ROOT" || exit 64

sha256_stdin() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 | awk '{print $1}'
  else sha256sum | awk '{print $1}'; fi
}

# The body's bytes exactly as GitHub stores them: `jq -j` adds no newline.
body_hash() {
  local json
  json="$(gh issue view "$ISSUE" --json body 2>/dev/null)" || return 1
  printf '%s' "$json" | jq -j '.body // ""' 2>/dev/null | sha256_stdin
}

h="$(body_hash)" || { echo "[$TAG] issue #$ISSUE: body lookup failed (gh issue view)" >&2; exit 3; }
echo "$h"
exit 0
