#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
# =============================================================================
# Criterion readiness — whether the [criterion-ready] entry of an attempt's
# criterion review holds for the issue body as it stands now (issues #430,
# #465; docs/criterion-review.md, docs/decision-ledger.md)
# =============================================================================
# Reads and reports (ADR-0025 D8). It changes nothing: no ledger entry, no
# file, no issue edit. Whether an issue's acceptance criteria are right is not
# judged here — that is the criterion review's (docs/criterion-review.md).
# This script reads only whether the review's [criterion-ready] entry — the
# record of the decisions settled under the policy the operator set — is on
# record for the issue body as it stands now. What follows a READY or a NOT
# READY is the Coordinator's (ADR-0038 D2).
#
# Readiness belongs to one attempt: its entry is read from the attempt's own
# record directory, the one the Coordinator builds and names with --records
# (ADR-0038 D4) — never from another attempt's.
#
# The entry read is the LAST level-2 ledger entry whose heading ends in the
# marker `[criterion-ready]`, in the attempt's ledger `issue-<N>-ledger.md`. It
# counts only when:
#   - its identifier is in the `O` namespace and its `- Authority:` line reads
#     `operator decision` (the gate hook admits both from the main session
#     only — docs/decision-ledger.md, docs/core.md > Records and the hook);
#   - its `- Record:` line names a review record that exists — a path relative
#     to the attempt's record directory, a run's subdirectory included
#     (`criterion-reconcile-<n>/criterion-review.md`); an absolute path or one
#     with a `..` component never counts, so another attempt's record does not;
#   - its `- Issue body sha256:` line equals the sha256 of the issue body read
#     from GitHub now, so an issue edited after the entry is not ready.
#
# Subcommands:
#   hash   --issue N                       print the sha256 of the issue body
#                                          as it stands now — the value an
#                                          entry records
#   status --issue N --records <dir>       READY / NOT READY, with the reason
#
# Exit codes:
#   0   hash printed | READY
#   1   NOT READY — no ledger, no [criterion-ready] entry, a malformed one, a
#       missing record, or an issue body changed since the entry; the line
#       says which
#   3   a fact could not be read — the issue body lookup failed
#   64  usage
#
# Usage: scripts/preflight/criterion-ready.sh hash --issue N
#        scripts/preflight/criterion-ready.sh status --issue N --records <attempt-dir>
# =============================================================================

set -uo pipefail

TAG="criterion-ready"
usage() { echo "Usage: $0 hash --issue N | $0 status --issue N --records <attempt-dir>" >&2; exit 64; }

SUB="${1:-}"
[ "$#" -gt 0 ] && shift
case "$SUB" in hash|status) ;; -h|--help) echo "Usage: $0 hash --issue N | $0 status --issue N --records <attempt-dir>"; exit 0 ;; *) usage ;; esac
ISSUE=""
DIR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --issue) [ $# -ge 2 ] || usage; ISSUE="${2#\#}"; shift 2 ;;
    --records) [ $# -ge 2 ] || usage; DIR="$2"; shift 2 ;;
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

if [ "$SUB" = hash ]; then
  h="$(body_hash)" || { echo "[$TAG] issue #$ISSUE: body lookup failed (gh issue view)" >&2; exit 3; }
  echo "$h"
  exit 0
fi

not_ready() { echo "$TAG: issue #$ISSUE NOT READY — $1"; exit 1; }

[ -n "$DIR" ] || { echo "[$TAG] status takes the attempt's record directory: --records <attempt-dir>" >&2; usage; }
[ -d "$DIR" ] || { echo "[$TAG] --records is not a directory: $DIR" >&2; exit 64; }
DIR="$(cd -P "$DIR" && pwd)"
LEDGER="$DIR/issue-$ISSUE-ledger.md"

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
case "/$rec/" in //*|*/../*|*/./*|*//*) not_ready "entry $id: '- Record:' is '$rec' — the review record is a path relative to the attempt's record directory, with no '.' or '..' component" ;; esac
recp="$DIR/$rec"
[ -f "$recp" ] || not_ready "entry $id: review record '$rec' does not exist ($recp)"
printf '%s' "$sha" | grep -Eq '^[0-9a-f]{64}$' || not_ready "entry $id: '- Issue body sha256:' is not a sha256 ('$sha')"

now="$(body_hash)" || { echo "[$TAG] issue #$ISSUE: body lookup failed (gh issue view)" >&2; exit 3; }
[ "$now" = "$sha" ] || not_ready "entry $id records body sha256=$sha, the issue body now is sha256=$now — the issue changed since the entry; a new entry records the edited body"

echo "$TAG: issue #$ISSUE READY — attempt $DIR, entry $id, record $rec, body sha256=$sha"
exit 0
