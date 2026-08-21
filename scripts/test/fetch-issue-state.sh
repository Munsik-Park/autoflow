#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# fetch-issue-state.sh — the issue-state fetch adapter (issue #122)
# =============================================================================
# WHAT THIS IS, AND WHY IT IS A SEPARATE FILE. scripts/test/check-suite-manifest.sh
# carries an ADVISORY retirement-due leg: a `lane: cycle-scoped` suite whose
# `retire-with:` issue is already closed is due for deletion. Deciding whether an
# issue is closed is not derivable from the tree — it needs a network call — and
# check-suite-manifest.sh is a GATING lint registered as an unguarded step in
# .github/workflows/contract-suites.yml. Putting a network dependency inside it
# would turn a GitHub outage, an unauthenticated runner or an offline checkout
# into a red build.
#
# So the leg is split at an injection boundary. The PURE CLASSIFIER lives in the
# lint and reads only a record file. This THIN FETCH ADAPTER lives here, outside
# it, and produces that record.
#
# INVOKER: an operator, or a workflow step that chooses to. NEVER
# check-suite-manifest.sh — the lint does not invoke this script, does not
# reference its path in any executable position, and performs no network access
# of its own. That is the property the seam exists to keep true.
#
# Usage:
#   bash scripts/test/fetch-issue-state.sh [--out <path>] [--repo <owner/name>]
#
# Writes one `#<issue> <open|closed|unknown>` line per `retire-with:` issue found
# in the tree's suite headers. Default --out is ./.autoflow/issue-state.txt.
# Then point the lint at it:
#   AUTOFLOW_ISSUE_STATE_FILE=<path> bash scripts/test/check-suite-manifest.sh
#
# DEGRADED BEHAVIOUR IS EXPLICIT, HERE TOO. With no usable `gh` — absent,
# unauthenticated, rate-limited — every issue is written `unknown` rather than
# omitted, and the exit status is 0. An omitted line and an `unknown` line are
# not the same thing to the classifier: `unknown` puts the suite in the loud
# "could not decide" list, while a silently missing record would be
# indistinguishable from a decision.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=scripts/test/suite-manifest.sh
. "$SCRIPT_DIR/suite-manifest.sh"

OUT="$ROOT/.autoflow/issue-state.txt"
REPO=""
while [ $# -gt 0 ]; do
  case "$1" in
    --out)  require_value fetch-issue-state "$1" $# "${2:-}" || exit 2; OUT="$2"; shift ;;
    --repo) require_value fetch-issue-state "$1" $# "${2:-}" || exit 2; REPO="$2"; shift ;;
    *)      echo "fetch-issue-state: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

issue_state() {  # <#N> -> open|closed|unknown
  local n="${1#\#}" state
  command -v gh >/dev/null 2>&1 || { echo unknown; return 0; }
  if [ -n "$REPO" ]; then
    state="$(gh issue view "$n" --repo "$REPO" --json state --jq '.state' 2>/dev/null || true)"
  else
    state="$(gh issue view "$n" --json state --jq '.state' 2>/dev/null || true)"
  fi
  case "$state" in
    OPEN|open)     echo open ;;
    CLOSED|closed) echo closed ;;
    *)             echo unknown ;;
  esac
}

mkdir -p "$(dirname "$OUT")"
: > "$OUT"
seen=""
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  retire="$(suite_header_field "$ROOT/$rel" retire-with 2>/dev/null || true)"
  [ -n "$retire" ] || continue
  case " $seen " in *" $retire "*) continue ;; esac
  seen="$seen $retire"
  printf '%s %s\n' "$retire" "$(issue_state "$retire")" >> "$OUT"
done < <(suite_enumerate "$ROOT")

echo "fetch-issue-state: wrote $(grep -c . "$OUT") record(s) to $OUT"
