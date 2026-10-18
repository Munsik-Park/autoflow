#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Criterion readiness — the fact PREFLIGHT reads before a new-issue cycle
# (issue #430; docs/criterion-review.md)
# =============================================================================
# Reads and reports (ADR-0025 D8). It changes nothing: no ledger entry, no
# file, no issue edit. Whether an issue's acceptance criteria are right is not
# judged here — that is the criterion review's (docs/criterion-review.md).
# This script reads only whether the review's [criterion-ready] entry — the
# record of the decisions settled under the policy the operator set — is on
# record for the issue body as it stands now.
#
# Readiness belongs to one attempt (issue #466): each attempt starts with its
# own criterion review, and its entry is read from its own record directory —
# never from another attempt's, of this checkout or another. The attempt is the
# one of the dev branch named with --branch, by default the checked-out branch:
# `<record-root>/<repo-key>/<stamp>-issue-<N>/` (scripts/lib/records.sh).
#
# The entry read is the LAST level-2 ledger entry whose heading ends in the
# marker `[criterion-ready]`, in the attempt's ledger `issue-<N>-ledger.md`. It
# counts only when:
#   - its identifier is in the `O` namespace and its `- Authority:` line reads
#     `operator decision` (the gate hook admits both from the main session
#     only — docs/state-tracking.md > Hook gates);
#   - its `- Record:` line names a review record that exists — a file name in
#     the attempt's own directory (no `/`: another attempt's record never counts);
#   - its `- Issue body sha256:` line equals the sha256 of the issue body read
#     from GitHub now, so an issue edited after the entry is not ready.
# and only while the attempt has no state file: an attempt that has started
# takes no [criterion-ready] entry (a criterion change inside a cycle is an
# [ac-decision]). Another attempt's state file or records under the record
# root are no reason for NOT READY.
#
# Subcommands:
#   hash   --issue N                 print the sha256 of the issue body as it
#                                    stands now — the value an entry records
#   status --issue N [--branch B]    READY / NOT READY, with the reason
#
# Exit codes:
#   0   hash printed | READY
#   1   NOT READY — not an attempt of issue N, no [criterion-ready] entry, a
#       malformed one, a missing record, an issue body changed since the entry,
#       or an attempt that has started; the line says which
#   3   a fact could not be read — the issue body lookup failed
#   7   the record root is undetermined or unusable (the marker line says why)
#   64  usage
#
# Usage: scripts/preflight/criterion-ready.sh {hash|status} --issue N [--branch B]
# =============================================================================

set -uo pipefail

TAG="criterion-ready"
usage() { echo "Usage: $0 {hash|status} --issue N [--branch B]" >&2; exit 64; }

SUB="${1:-}"
[ "$#" -gt 0 ] && shift
case "$SUB" in hash|status) ;; -h|--help) echo "Usage: $0 {hash|status} --issue N [--branch B]"; exit 0 ;; *) usage ;; esac
ISSUE=""
BRANCH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --issue) [ $# -ge 2 ] || usage; ISSUE="${2#\#}"; shift 2 ;;
    --branch) [ $# -ge 2 ] || usage; BRANCH="$2"; shift 2 ;;
    *) echo "[$TAG] unknown argument: $1" >&2; usage ;;
  esac
done
case "$ISSUE" in ''|*[!0-9]*) echo "[$TAG] --issue takes an issue number: '$ISSUE'" >&2; usage ;; esac

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "[$TAG] not inside a git repository" >&2; exit 64; }
cd "$ROOT" || exit 64
# shellcheck source=scripts/lib/records.sh
. "$SELF_DIR/../lib/records.sh"

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

TOP="$(af_checkout_top "$ROOT")"
if ! af_record_root "$TOP"; then
  af_record_root_marker
  exit "$AF_RECORD_ROOT_EXIT"
fi
[ -n "$BRANCH" ] || BRANCH="$(git symbolic-ref --quiet --short HEAD 2>/dev/null)" || BRANCH=""
KEYA="$(af_attempt_key "$BRANCH")" || not_ready "'${BRANCH:-(detached HEAD)}' is not an attempt's dev branch — a new attempt begins with its criterion review"
[ "$(af_attempt_issue "$KEYA")" = "$ISSUE" ] || not_ready "'$BRANCH' is an attempt of issue #$(af_attempt_issue "$KEYA"), not #$ISSUE"
DIR="$AF_RECORD_ROOT/$(autoflow_repo_key "$ROOT")/$KEYA"
LEDGER="$DIR/issue-$ISSUE-ledger.md"
[ -d "$DIR" ] || not_ready "no attempt record at $DIR — a new attempt begins with its criterion review"
[ -f "$DIR/issue-$ISSUE.json" ] && not_ready "the attempt $KEYA has started ($DIR/issue-$ISSUE.json) — an attempt takes its [criterion-ready] entry before its state file, and a criterion change inside a cycle is an [ac-decision]"

[ -f "$LEDGER" ] || not_ready "no ledger ($LEDGER), so no [criterion-ready] entry"

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

[[ "$id" =~ ^O[0-9]+$ ]] || not_ready "entry $id is not an O entry (O<digits>) — a [criterion-ready] entry is an O entry under 'operator decision'"
[ "$auth" = "operator decision" ] || not_ready "entry $id: '- Authority:' is '$auth', not 'operator decision'"
[ -n "$rec" ] || not_ready "entry $id: no '- Record:' line"
case "$rec" in */*) not_ready "entry $id: '- Record:' is '$rec' — the review record is a file name in the attempt's own directory" ;; esac
recp="$DIR/$rec"
[ -f "$recp" ] || not_ready "entry $id: review record '$rec' does not exist ($recp)"
printf '%s' "$sha" | grep -Eq '^[0-9a-f]{64}$' || not_ready "entry $id: '- Issue body sha256:' is not a sha256 ('$sha')"

now="$(body_hash)" || { echo "[$TAG] issue #$ISSUE: body lookup failed (gh issue view)" >&2; exit 3; }
[ "$now" = "$sha" ] || not_ready "entry $id records body sha256=$sha, the issue body now is sha256=$now — the issue changed since the entry; the criterion review records a new entry for the edited body"

echo "$TAG: issue #$ISSUE READY — attempt $KEYA, entry $id, record $rec, body sha256=$sha"
exit 0
