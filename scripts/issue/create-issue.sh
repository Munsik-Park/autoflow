#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# scripts/issue/create-issue.sh
#
# AutoFlow issue-creation wrapper — layer two of the three-layer gate on
# AI-initiated issue filing (issue #96). Layer one is the hook's unconditional
# `gh issue create` deny (.claude/hooks/check-autoflow-gate.sh > Section 1);
# layer three is the operator's own permission allow-list, which this script is
# deliberately never added to, so every invocation raises an approval prompt.
#
# WHY A WRAPPER: the review obligation that precedes filing an issue was prose
# only. An agent could assert "I searched for duplicates" in its own words and
# file anyway — the assertion and the act had no mechanical relation. This
# script makes the filing DERIVE from a draft on disk and RE-RUNS the duplicate
# search itself, from terms it derives from the draft's own title, so a
# self-report can neither substitute for the search nor narrow it. The draft's
# recorded `searched:` line only ever ADDS terms; it can never remove one.
#
# The draft must live at the TOP LEVEL of `.autoflow/` so the cycle's archive
# sweep (scripts/cleanup/cleanup-issue.sh, maxdepth 1) collects the created
# issue's proposal record with the rest of its files. On success the draft is
# renamed to `.autoflow/issue-<N>-proposal.md`, binding the record to the
# number GitHub actually assigned rather than to a guess.
#
# Usage:
#   scripts/issue/create-issue.sh --draft .autoflow/<name>.md [--dry-run]
#
# Draft grammar: docs/issue-proposal.md. Sections are `## `-headed and may
# appear in any order: `## Title`, `## Grounds`, `## Duplicate check`
# (carrying a `searched:` line), `## Body`.
#
# Exit codes:
#   0   created (or --dry-run: every check passed, nothing was created)
#   64  usage / precondition error — bad arguments, no `.autoflow/`, draft
#       outside `.autoflow/`'s top level
#   65  draft-data error — malformed draft, underivable title, a duplicate
#       candidate recalled, or a search page that came back saturated
#   70  gh reported success but its output could not be bound to an issue
#       number
#   *   gh's own non-zero exit, propagated

set -uo pipefail
# The term derivation splits titles on whitespace with unquoted expansion; the
# script expands no globs of its own, so pathname expansion is disabled outright
# rather than guarded token by token.
set -f

PAGE_LIMIT=100        # gh's page size for the per-term search
ASCII_FLOOR=4           # minimum codepoints for an all-ASCII search term
NON_ASCII_FLOOR=2       # minimum codepoints for a term carrying non-ASCII

usage() {
  cat >&2 <<'EOF'
usage: scripts/issue/create-issue.sh --draft <.autoflow/<name>.md> [--dry-run]

  --draft <path>  proposal draft at the TOP LEVEL of the repo's .autoflow/
  --dry-run       run every check and print the plan; create nothing

Draft grammar: docs/issue-proposal.md
EOF
}

# ── Arguments ───────────────────────────────────────────────────────────────
# The derivation rule is deliberately NOT tunable: no flag widens, narrows, or
# caps the term set. A caller that could pass `--term-cap 1` could satisfy the
# duplicate check by shrinking it, which is the failure mode this script exists
# to remove. An unrecognised flag is a usage error, never a silent no-op.
DRAFT=""
DRY_RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --draft)
      if [ $# -lt 2 ]; then
        echo "refuse: --draft requires a path" >&2
        usage
        exit 64
      fi
      DRAFT="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    *)
      echo "refuse: unrecognised argument '$1' — the duplicate-search derivation takes no options" >&2
      usage
      exit 64
      ;;
  esac
done

if [ -z "$DRAFT" ]; then
  echo "refuse: --draft is required — an issue is filed from a draft on disk, never from arguments alone" >&2
  usage
  exit 64
fi

# ── Repository and .autoflow/ preconditions ─────────────────────────────────
if ! ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  echo "refuse: not inside a Git repository — .autoflow/ is resolved from the repo root" >&2
  exit 64
fi
# Compare PHYSICAL paths on both sides: on macOS the repo root frequently
# resolves through a symlinked ancestor (/var -> /private/var), so a textual
# prefix test would reject a draft that really is inside .autoflow/.
if ! ROOT_PHYS="$(cd -P "$ROOT" 2>/dev/null && pwd)"; then
  echo "refuse: repository root '$ROOT' cannot be resolved" >&2
  exit 64
fi
AUTOFLOW_DIR="$ROOT_PHYS/.autoflow"

if [ ! -d "$AUTOFLOW_DIR" ]; then
  echo "refuse: no .autoflow/ directory at $ROOT_PHYS — create it before filing from a draft" >&2
  exit 64
fi

if [ ! -f "$DRAFT" ]; then
  echo "refuse: draft not found: $DRAFT" >&2
  exit 64
fi
# A symlinked draft is refused rather than resolved: the containment rule below
# is what makes the archive sweep reach the record, and a link whose target
# lives elsewhere satisfies the rule while defeating its purpose. Refusing is
# the conservative reading — no test in this cycle's suite pins the case.
if [ -L "$DRAFT" ]; then
  echo "refuse: draft is a symlink: $DRAFT — place the draft itself in .autoflow/" >&2
  exit 64
fi
DRAFT_DIR="$(cd -P "$(dirname "$DRAFT")" 2>/dev/null && pwd)" || {
  echo "refuse: draft directory cannot be resolved: $DRAFT" >&2
  exit 64
}
if [ "$DRAFT_DIR" != "$AUTOFLOW_DIR" ]; then
  echo "refuse: draft must live at the top level of $AUTOFLOW_DIR (found it in $DRAFT_DIR) — a subdirectory lies outside the maxdepth-1 archive sweep" >&2
  exit 64
fi
DRAFT_PATH="$DRAFT_DIR/$(basename "$DRAFT")"

# ── Draft parsing ───────────────────────────────────────────────────────────
# Sections are `## `-headed and order-independent; a section body runs to the
# next `## ` heading.
has_section() { grep -qxF "## $1" "$DRAFT_PATH"; }

section_body() {
  awk -v want="$1" '
    /^## / { insec = (substr($0, 4) == want) ? 1 : 0; next }
    insec  { print }
  ' "$DRAFT_PATH" | trim_blank_edges
}

trim_blank_edges() {
  awk '
    { line[n++] = $0 }
    END {
      first = 0
      while (first < n && line[first] ~ /^[[:space:]]*$/) first++
      last = n - 1
      while (last >= first && line[last] ~ /^[[:space:]]*$/) last--
      for (i = first; i <= last; i++) print line[i]
    }
  '
}

if ! has_section "Title"; then
  echo "refuse: draft has no '## Title' section: $DRAFT_PATH" >&2
  exit 65
fi
TITLE="$(section_body "Title" | head -1)"
if [ -z "$TITLE" ]; then
  echo "refuse: draft's '## Title' section is empty: $DRAFT_PATH" >&2
  exit 65
fi

if ! has_section "Body"; then
  echo "refuse: draft has no '## Body' section: $DRAFT_PATH" >&2
  exit 65
fi
BODY="$(section_body "Body")"
if [ -z "$BODY" ]; then
  echo "refuse: draft's '## Body' section is empty: $DRAFT_PATH" >&2
  exit 65
fi

# Grounds must carry a verifiable anchor — a `path:line`, a commit SHA, or a
# URL — so the proposal rests on something a reader can re-derive rather than
# on the author's summary of it (CLAUDE.md > Execution Principles).
GROUNDS="$(section_body "Grounds")"
if ! printf '%s' "$GROUNDS" | grep -qE '([^[:space:]]+:[0-9]+)|(^|[^0-9A-Za-z])[0-9a-f]{7,40}([^0-9A-Za-z]|$)|https?://'; then
  echo "refuse: draft's '## Grounds' section carries no anchor — state a path:line, a commit SHA, or a URL: $DRAFT_PATH" >&2
  exit 65
fi

DUPCHECK="$(section_body "Duplicate check")"
SEARCHED_LINE="$(printf '%s\n' "$DUPCHECK" | grep -m1 '^searched:' || true)"
if [ -z "$SEARCHED_LINE" ]; then
  echo "refuse: draft's '## Duplicate check' section has no 'searched:' line: $DRAFT_PATH" >&2
  exit 65
fi

# ── Search-term derivation ──────────────────────────────────────────────────
# Every primitive below is byte-oriented under LC_ALL=C, so the derived term
# set — and therefore the query sequence — is identical under every locale. A
# `wc -m` length would count a Korean syllable as 1 under a UTF-8 locale and 3
# under C, deriving a DIFFERENT set of queries depending on the operator's
# environment.

# codepoint_len <token> — UTF-8 codepoints, counted without a locale: every
# byte outside the continuation range 0x80-0xBF starts one codepoint.
codepoint_len() {
  LC_ALL=C printf '%s' "$1" | LC_ALL=C tr -d '\200-\277' | LC_ALL=C wc -c | tr -d '[:space:]'
}

# is_non_ascii <token> — true when any byte lies outside printable ASCII.
is_non_ascii() {
  LC_ALL=C printf '%s' "$1" | LC_ALL=C grep -q '[^ -~]'
}

# terms_from <text> — whitespace tokens that clear their floor, in order.
# Tokens below the floor are dropped rather than queried: a 1-2 character
# fragment matches most of the tracker and would make every draft collide.
terms_from() {
  local tok len
  for tok in $1; do
    len="$(codepoint_len "$tok")"
    if is_non_ascii "$tok"; then
      [ "$len" -ge "$NON_ASCII_FLOOR" ] && printf '%s\n' "$tok"
    else
      [ "$len" -ge "$ASCII_FLOOR" ] && printf '%s\n' "$tok"
    fi
  done
  return 0
}

# A leading bracket tag ([fix], [chore], …) classifies the issue; it is shared
# by a large share of the tracker and carries no subject matter, so it is not a
# duplicate signal. Only a LEADING tag is stripped.
TITLE_WORDS="$(printf '%s' "$TITLE" | sed -E 's/^\[[^]]*\][[:space:]]*//')"
TITLE_TERMS="$(terms_from "$TITLE_WORDS")"

if [ -z "$TITLE_TERMS" ]; then
  echo "refuse: no search term derives from the title '$TITLE' — every word is below the length floor, so the duplicate check would be vacuous" >&2
  exit 65
fi

# The recorded `searched:` line is ADDITIVE only. Its terms are unioned onto
# the title-derived set; it can never remove one, so a draft cannot narrow its
# own duplicate check by under-reporting what it searched.
SEARCHED_TERMS="$(terms_from "${SEARCHED_LINE#searched:}")"

TERMS=""
for term in $TITLE_TERMS $SEARCHED_TERMS; do
  case "
$TERMS" in
    *"
$term
"*) continue ;;
  esac
  TERMS="$TERMS$term
"
done

# ── Duplicate re-check ──────────────────────────────────────────────────────
# One query per term. A single joined query would be an AND over the terms and
# would recall nothing but a near-identical title; the union over per-term
# queries is what recalls a paraphrase.
#
# Scope: OPEN issues. A closed issue is a decision already taken — resolved,
# rejected, or superseded — so it is not work in flight that a new filing would
# duplicate, and matching against the closed archive turns every common word in
# a title into a refusal the author can only clear by rewording. The obligation
# this script mechanizes is "do not file over live work"; a deliberate re-file
# against a closed decision belongs to the author, with the grounds to say so.
CANDIDATES=""
SATURATED=""
while IFS= read -r term; do
  [ -n "$term" ] || continue
  if ! rows="$(gh issue list --search "$term" --state open --limit "$PAGE_LIMIT" --json number,title,state 2>/dev/null)"; then
    echo "refuse: 'gh issue list --search $term' failed — the duplicate check could not be completed" >&2
    exit 65
  fi
  count="$(printf '%s' "$rows" | jq 'length' 2>/dev/null)" || count=0
  if [ "${count:-0}" -ge "$PAGE_LIMIT" ]; then
    # A full page means the result set was cut off, so "no duplicate among
    # these" is a statement about the page, not about the tracker. Refuse
    # rather than create on a truncated answer.
    SATURATED="$SATURATED$term
"
    continue
  fi
  # The state scope is re-applied here, not left to the `--state open` flag
  # alone: the flag is what a live `gh` honours, this filter is what makes the
  # scope a property of the wrapper rather than of the search backend.
  CANDIDATES="$CANDIDATES$(printf '%s' "$rows" | jq -r '.[] | select(.state == "OPEN") | "  #\(.number) \(.title)"')
"
done <<EOF
$TERMS
EOF

if [ -n "$(printf '%s' "$SATURATED" | tr -d '[:space:]')" ]; then
  echo "refuse: the duplicate search returned a saturated page (${PAGE_LIMIT} results) for these terms, so it cannot rule out a duplicate:" >&2
  printf '%s' "$SATURATED" | sed 's/^/  /' >&2
  exit 65
fi

if [ -n "$(printf '%s' "$CANDIDATES" | tr -d '[:space:]')" ]; then
  echo "refuse: the duplicate search recalled existing issue(s) — review them before filing '$TITLE':" >&2
  printf '%s' "$CANDIDATES" | grep -v '^[[:space:]]*$' | sort -u >&2
  exit 65
fi

# ── Creation ────────────────────────────────────────────────────────────────
if [ "$DRY_RUN" = 1 ]; then
  echo "dry-run: every check passed for '$TITLE' — nothing created, $DRAFT_PATH left in place"
  exit 0
fi

BODY_FILE="$(mktemp)"
trap 'rm -f "$BODY_FILE"' EXIT
printf '%s\n' "$BODY" > "$BODY_FILE"

# Only the `## Body` section reaches the issue. Grounds and the duplicate-check
# record are the wrapper's own inputs — they stay in the draft, which the
# rename below preserves verbatim as the cycle's proposal record.
# `rc` is captured from the assignment itself, not from inside an `if !` block:
# negating the command resets `$?` to 0 and would turn gh's own failure into a
# success exit.
URL="$(gh issue create --title "$TITLE" --body-file "$BODY_FILE")"
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "refuse: 'gh issue create' failed (exit $rc) — $DRAFT_PATH left in place" >&2
  exit "$rc"
fi

NUMBER="${URL##*/}"
case "$NUMBER" in
  '' | *[!0-9]*)
    echo "refuse: cannot read an issue number from gh's output ('$URL') — $DRAFT_PATH left in place rather than renamed to a guessed number" >&2
    exit 70
    ;;
esac

RECORD="$AUTOFLOW_DIR/issue-${NUMBER}-proposal.md"
if ! mv "$DRAFT_PATH" "$RECORD"; then
  echo "warn: issue #$NUMBER was created but $DRAFT_PATH could not be renamed to $RECORD" >&2
  exit 70
fi

echo "created issue #$NUMBER — $URL"
echo "proposal record: $RECORD"
exit 0
