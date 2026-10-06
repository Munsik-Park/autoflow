#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Criterion readiness — the fact PREFLIGHT reads before a new-issue cycle
# (issue #430; docs/criterion-review.md)
# =============================================================================
# Reads and reports (ADR-0025 D8). It changes nothing: no ledger entry, no
# file, no issue edit. Whether an issue's acceptance criteria are right is not
# judged here — that is the criterion review's and the operator's
# (docs/criterion-review.md). This script reads only whether the operator's
# confirmation is on record for the issue body as it stands now.
#
# The confirmation is the LAST level-2 ledger entry whose heading ends in the
# marker `[criterion-ready]`, in the issue's ledger
# `.autoflow/<repo-key>-issue-<N>/issue-<N>-ledger.md`. It counts only when:
#   - its identifier is in the `O` namespace and its `- Authority:` line reads
#     `operator decision` (the gate hook admits both from the main session
#     only — CLAUDE.md > Hook gates);
#   - its `- Record:` line names a review record that exists (repo-relative);
#   - its `- Issue body sha256:` line equals the sha256 of the issue body read
#     from GitHub now, so an issue edited after the confirmation is not ready.
# and only while the issue directory holds no earlier cycle's state file, which
# PREFLIGHT would archive — with the confirmation — before reading readiness.
#
# Subcommands:
#   hash   --issue N   print the sha256 of the issue body as it stands now —
#                      the value a confirmation entry records
#   status --issue N   READY / NOT READY, with the reason
#
# Exit codes:
#   0   hash printed | READY
#   1   NOT READY — no confirmation, a malformed one, a missing record, an
#       issue body changed since the confirmation, or an earlier cycle's state
#       file still in the directory; the line says which
#   3   a fact could not be read — the issue body lookup failed
#   64  usage
#
# Usage: scripts/preflight/criterion-ready.sh {hash|status} --issue N
# =============================================================================

set -uo pipefail

TAG="criterion-ready"
usage() { echo "Usage: $0 {hash|status} --issue N" >&2; exit 64; }

SUB="${1:-}"
[ "$#" -gt 0 ] && shift
case "$SUB" in hash|status) ;; -h|--help) echo "Usage: $0 {hash|status} --issue N"; exit 0 ;; *) usage ;; esac
ISSUE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --issue) [ $# -ge 2 ] || usage; ISSUE="${2#\#}"; shift 2 ;;
    *) echo "[$TAG] unknown argument: $1" >&2; usage ;;
  esac
done
case "$ISSUE" in ''|*[!0-9]*) echo "[$TAG] --issue takes an issue number: '$ISSUE'" >&2; usage ;; esac

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "[$TAG] not inside a git repository" >&2; exit 64; }
cd "$ROOT" || exit 64
# shellcheck source=scripts/lib/issue-dir.sh
. "$SELF_DIR/../lib/issue-dir.sh"
DIR="$(autoflow_issue_dir "$ROOT" "$ISSUE")"
LEDGER="$DIR/issue-$ISSUE-ledger.md"

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

if [ "$SUB" = hash ]; then
  h="$(body_hash)" || { echo "[$TAG] issue #$ISSUE: body lookup failed (gh issue view)" >&2; exit 3; }
  echo "$h"
  exit 0
fi

not_ready() { echo "$TAG: issue #$ISSUE NOT READY — $1"; exit 1; }

# PREFLIGHT archives an earlier cycle's directory before it reads readiness, so
# a confirmation sitting beside that cycle's state file would go with it
# (docs/criterion-review.md > When and by whom).
[ -f "$DIR/issue-$ISSUE.json" ] && not_ready "the issue directory still holds an earlier cycle's state file ($DIR/issue-$ISSUE.json); PREFLIGHT archives it, and any confirmation beside it, before reading readiness — clear that cycle first, then review and confirm"

[ -f "$LEDGER" ] || not_ready "no ledger ($LEDGER), so no [criterion-ready] confirmation"

# The last [criterion-ready] entry: its heading line and the lines up to the
# next level-2 heading, tab-separated as id, authority, record, sha256.
entry="$(awk '
  /^## / {
    inside = 0
    if ($0 ~ /\[criterion-ready\][[:space:]]*$/) {
      inside = 1; found = 1
      id = substr($0, 4); sub(/ .*$/, "", id)
      auth = ""; rec = ""; sha = ""
    }
    next
  }
  inside && /^- Authority: /         { auth = $0; sub(/^- Authority: /, "", auth) }
  inside && /^- Record: /            { rec = $0;  sub(/^- Record: /, "", rec) }
  inside && /^- Issue body sha256: / { sha = $0;  sub(/^- Issue body sha256: /, "", sha) }
  END { if (found) printf "%s\t%s\t%s\t%s\n", id, auth, rec, sha }
' "$LEDGER")"
[ -n "$entry" ] || not_ready "no [criterion-ready] entry in $LEDGER"

IFS=$'\t' read -r id auth rec sha <<EOF
$entry
EOF
trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; printf '%s' "${s%"${s##*[![:space:]]}"}"; }
auth="$(trim "${auth:-}")"; rec="$(trim "${rec:-}")"; rec="${rec#\`}"; rec="${rec%\`}"; sha="$(trim "${sha:-}")"

[[ "$id" =~ ^O[0-9]+$ ]] || not_ready "entry $id is not an O entry (O<digits>) — the confirmation is the operator's"
[ "$auth" = "operator decision" ] || not_ready "entry $id: '- Authority:' is '$auth', not 'operator decision'"
[ -n "$rec" ] || not_ready "entry $id: no '- Record:' line"
[ -f "$rec" ] || not_ready "entry $id: review record '$rec' does not exist"
printf '%s' "$sha" | grep -Eq '^[0-9a-f]{64}$' || not_ready "entry $id: '- Issue body sha256:' is not a sha256 ('$sha')"

now="$(body_hash)" || { echo "[$TAG] issue #$ISSUE: body lookup failed (gh issue view)" >&2; exit 3; }
[ "$now" = "$sha" ] || not_ready "entry $id confirmed body sha256=$sha, the issue body now is sha256=$now — the issue changed since the confirmation"

echo "$TAG: issue #$ISSUE READY — entry $id, record $rec, body sha256=$sha"
exit 0
