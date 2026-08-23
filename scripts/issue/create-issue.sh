#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# scripts/issue/create-issue.sh
#
# AutoFlow issue-creation wrapper — layer two of the three-layer gate on
# AI-initiated issue filing (issue #96, feature design §5). Layer one is the
# hook's unconditional `gh issue create` deny (.claude/hooks/check-autoflow-gate.sh
# > Section 1); layer three is the operator's own permission allow-list, which
# this script is deliberately never added to, so every invocation raises an
# approval prompt.
#
# WHY A WRAPPER: the obligation to check for duplicates before filing was prose
# only. An agent could assert it had searched and file anyway — the assertion and
# the act had no mechanical relation. This script re-runs the query itself, from
# terms it derives from the draft's OWN title, and then compares what that query
# returned against the candidates the draft dispositioned. It does not judge
# whether a disposition is correct (that is the operator's job at layer three);
# it refuses when the draft disposes of nothing the wrapper found.
#
# The draft must sit directly inside the derived `.autoflow/`, which is the
# directory the cleanup archive matcher searches at maxdepth 1. On a successful
# create the draft is renamed to `.autoflow/issue-<N>-proposal.md`, binding the
# record to the number GitHub actually assigned rather than to a guess.
#
# Usage:
#   scripts/issue/create-issue.sh --draft <path> [--repo <owner/name>] [--dry-run]
#
# Draft grammar: docs/issue-proposal.md (feature design §6). Four `## `-headed
# sections, order-independent: `## Title`, `## Grounds`, `## Duplicate check`,
# `## Body`.
#
# Exit codes:
#   0   created, or --dry-run with every check passed
#   64  usage / missing argument / draft not directly inside the derived
#       `.autoflow` (including that directory being absent)
#   65  refusal — missing section, no grounding anchor, no derivable query term,
#       an undispositioned candidate, or a query at its page limit
#   70  gh reported success but its output could not be bound to a number
#   *   gh's own non-zero exit, propagated

set -euo pipefail
# Term derivation splits on whitespace with unquoted expansion; the script
# expands no globs of its own, so pathname expansion is disabled outright.
set -f

# Derivation constants. Fixed in the script, never arguments: an agent-tunable
# derivation is an agent-authored query, which is the one thing layer 2 must not
# accept (feature design §5 step 2a, §9 disposition-strictness).
PAGE_LIMIT=100          # fixed page size; a full page is a fail-closed refusal
ASCII_FLOOR=4           # minimum codepoints for an all-[a-z0-9] term
NON_ASCII_FLOOR=2       # minimum codepoints for a term carrying non-ASCII
TERM_CAP=8              # maximum title-derived terms kept

usage() {
  cat >&2 <<'EOF'
usage: scripts/issue/create-issue.sh --draft <path> [--repo <owner/name>] [--dry-run]

  --draft <path>  proposal draft directly inside the repository's .autoflow/
  --repo <o/n>    target repository; defaults to the current repository's origin
  --dry-run       run every check and print the plan; create nothing

Draft grammar: docs/issue-proposal.md
EOF
}

# ── Arguments ───────────────────────────────────────────────────────────────
DRAFT=""
REPO=""
DRY_RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --draft)
      [ $# -ge 2 ] || { echo "refuse: --draft requires a path" >&2; usage; exit 64; }
      DRAFT="$2"; shift 2 ;;
    --repo)
      [ $# -ge 2 ] || { echo "refuse: --repo requires an owner/name" >&2; usage; exit 64; }
      REPO="$2"; shift 2 ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    *)
      echo "refuse: unrecognised argument '$1' — the derivation constants are fixed in the script and no argument alters them" >&2
      usage
      exit 64 ;;
  esac
done

if [ -z "$DRAFT" ]; then
  echo "refuse: --draft is required — an issue is filed from a draft on disk, never from arguments alone" >&2
  usage
  exit 64
fi

# gh target selection: pass --repo through only when the caller named one, so an
# unset value falls through to gh's own origin resolution rather than being sent
# as an empty argument.
GH_REPO_ARGS=""
[ -n "$REPO" ] && GH_REPO_ARGS="--repo $REPO"

# ── Repository and .autoflow/ preconditions ─────────────────────────────────
if ! ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  echo "refuse: not inside a Git repository — the .autoflow/ directory is derived from the repository root" >&2
  exit 64
fi
# Both sides of the containment test are compared as PHYSICAL paths. On macOS
# the repository root routinely resolves through a symlinked ancestor
# (/var -> /private/var), so a textual prefix test rejects a draft that really
# does sit inside .autoflow/.
if ! ROOT_PHYS="$(cd -P "$ROOT" 2>/dev/null && pwd)"; then
  echo "refuse: repository root '$ROOT' cannot be resolved" >&2
  exit 64
fi
AUTOFLOW_DIR="$ROOT_PHYS/.autoflow"

# The directory's absence is diagnosed separately from a misplaced draft
# (feature design §5): a target that has never run PREFLIGHT arrives here with no
# such directory, and "your draft is elsewhere" would not tell that caller that
# nothing is elsewhere. The wrapper does not create the directory — creating it
# would not make the draft appear.
if [ ! -d "$AUTOFLOW_DIR" ]; then
  echo "refuse: no .autoflow/ directory at $AUTOFLOW_DIR — write the draft into that directory and re-run; the wrapper does not create it" >&2
  exit 64
fi

if [ ! -f "$DRAFT" ]; then
  echo "refuse: draft is not a readable regular file: $DRAFT (expected directly inside $AUTOFLOW_DIR)" >&2
  exit 64
fi
# Symlink resolution (ledger E14 implementation note 4, left to the implementer
# against the constraint's intent): a symlinked draft is REFUSED, not resolved.
# The constraint exists so step 6's rename lands in the archive matcher's own
# maxdepth-1 slot; renaming a link moves the link, leaving the content outside
# every cycle's archival set — which satisfies the check while defeating what it
# is for. Refusing is the reading that preserves the intent.
if [ -L "$DRAFT" ]; then
  echo "refuse: draft is a symlink: $DRAFT — place the draft itself directly inside $AUTOFLOW_DIR" >&2
  exit 64
fi
if ! DRAFT_DIR="$(cd -P "$(dirname "$DRAFT")" 2>/dev/null && pwd)"; then
  echo "refuse: the draft's directory cannot be resolved: $DRAFT" >&2
  exit 64
fi
if [ "$DRAFT_DIR" != "$AUTOFLOW_DIR" ]; then
  echo "refuse: draft must sit directly inside $AUTOFLOW_DIR, but it resolved to $DRAFT_DIR — a subdirectory is archived into a different slot or into none" >&2
  exit 64
fi
DRAFT_PATH="$DRAFT_DIR/$(basename "$DRAFT")"

# ── Draft parsing (feature design §6) ───────────────────────────────────────
# Each section runs from its own level-2 heading to the next one or to end of
# file, and the four may appear in any order — which is what makes the body
# payload determinate regardless of where `## Body` sits.
has_section() { grep -qxF "## $1" "$DRAFT_PATH"; }

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

section_body() {
  awk -v want="$1" '
    /^## / { insec = (substr($0, 4) == want) ? 1 : 0; next }
    insec  { print }
  ' "$DRAFT_PATH" | trim_blank_edges
}

# Every missing element is named before exiting, so the caller can repair the
# draft without guessing (feature design §5 step 1).
MISSING=""
has_section "Title"          || MISSING="$MISSING  - the '## Title' section
"
has_section "Grounds"        || MISSING="$MISSING  - the '## Grounds' section
"
has_section "Duplicate check" || MISSING="$MISSING  - the '## Duplicate check' section
"
has_section "Body"           || MISSING="$MISSING  - the '## Body' section
"

TITLE=""
BODY=""
GROUNDS=""
DUPCHECK=""
SEARCHED_LINE=""
if has_section "Title"; then
  TITLE="$(section_body "Title" | head -1)"
  [ -n "$TITLE" ] || MISSING="$MISSING  - a non-empty title line under '## Title'
"
fi
if has_section "Body"; then
  BODY="$(section_body "Body")"
  [ -n "$BODY" ] || MISSING="$MISSING  - non-empty text under '## Body'
"
fi
if has_section "Grounds"; then
  GROUNDS="$(section_body "Grounds")"
  # An anchor is a path:line, a commit SHA, or a URL — something a reader can
  # re-derive rather than the author's summary of it.
  if ! printf '%s' "$GROUNDS" | grep -qE '([^[:space:]]+:[0-9]+)|(^|[^0-9A-Za-z])[0-9a-f]{7,40}([^0-9A-Za-z]|$)|https?://'; then
    MISSING="$MISSING  - a grounding anchor under '## Grounds' (a path:line, a commit SHA, or a URL)
"
  fi
fi
if has_section "Duplicate check"; then
  DUPCHECK="$(section_body "Duplicate check")"
  SEARCHED_LINE="$(printf '%s\n' "$DUPCHECK" | grep -m1 '^searched:' || true)"
  if [ -z "$(printf '%s' "${SEARCHED_LINE#searched:}" | tr -d '[:space:]')" ]; then
    MISSING="$MISSING  - a non-empty 'searched:' line under '## Duplicate check'
"
  fi
fi

if [ -n "$MISSING" ]; then
  echo "refuse: draft does not satisfy the grammar in docs/issue-proposal.md: $DRAFT_PATH" >&2
  printf '%s' "$MISSING" >&2
  exit 65
fi

# ── Term derivation (feature design §5 step 2) ──────────────────────────────
# Every primitive is byte-oriented under LC_ALL=C so the derived sequence — and
# therefore the query — is identical under every locale. `wc -m` is not used: it
# counts a Korean syllable as 3 under C and 1 under UTF-8, putting a
# single-codepoint token on opposite sides of the non-ASCII floor depending on
# the operator's environment.

# normalize_tokens — stdin text to one token per line, applying the shared
# lowercase / separator rule. ASCII-range lowercase only (case folding outside
# ASCII is script-dependent and is not attempted). Every ASCII character that is
# neither alphanumeric nor whitespace is a separator; bytes outside the ASCII
# range are NEVER separators and are never dropped, so a non-ASCII run survives
# as one token. The complement class is spelled out rather than using
# `[^[:alnum:]]`, which under LC_ALL=C erases non-ASCII bytes outright (ledger
# E14 implementation note 1).
normalize_tokens() {
  LC_ALL=C tr 'A-Z' 'a-z' \
    | LC_ALL=C tr -c 'a-z0-9\200-\377' '\n' \
    | grep -v '^$' || true
}

# codepoint_len — UTF-8 codepoints counted without a locale: every byte outside
# the continuation range 0x80-0xBF starts one codepoint.
codepoint_len() {
  LC_ALL=C printf '%s' "$1" | LC_ALL=C tr -d '\200-\277' | LC_ALL=C wc -c | tr -d '[:space:]'
}

has_non_ascii() { LC_ALL=C printf '%s' "$1" | LC_ALL=C grep -q '[^ -~]'; }

# contains_line — true if $2 appears as a whole line within the
# newline-terminated list in $1. Shared by the two term-dedup loops below
# (title-derived terms, then recorded terms), which otherwise repeat the same
# containment check verbatim.
contains_line() {
  case "
$1" in *"
$2
"*) return 0 ;; esac
  return 1
}

# A leading bracket tag is a structural type marker, not content: the commonest
# tag word matches over half this tracker, so admitting it would spend a term
# slot on the least discriminating token available.
TITLE_STRIPPED="$(printf '%s' "$TITLE" | sed -E 's/^\[[^]]*\][[:space:]]*//')"

# Title terms: floors by token class, dedup keeping first appearance, then cap.
TITLE_TERMS=""
kept=0
while IFS= read -r tok; do
  [ -n "$tok" ] || continue
  [ "$kept" -lt "$TERM_CAP" ] || break
  len="$(codepoint_len "$tok")"
  if has_non_ascii "$tok"; then
    [ "$len" -ge "$NON_ASCII_FLOOR" ] || continue
  else
    [ "$len" -ge "$ASCII_FLOOR" ] || continue
  fi
  contains_line "$TITLE_TERMS" "$tok" && continue
  TITLE_TERMS="$TITLE_TERMS$tok
"
  kept=$((kept + 1))
done <<EOF
$(printf '%s' "$TITLE_STRIPPED" | normalize_tokens)
EOF

# An empty title-derived set is a refusal, not an empty query. With it empty the
# query list would collapse to the draft's own recorded terms, and the wrapper
# would be re-running the agent's search while calling it independent
# verification — layer 2's whole claim is that at least one term came from the
# wrapper, and this is where that claim is enforced rather than assumed.
if [ -z "$TITLE_TERMS" ]; then
  echo "refuse: no query term derives from the title line '$TITLE' — every token falls below the derivation floor, so the duplicate check would be vacuous" >&2
  exit 65
fi

# Recorded terms: same lowercase / separator rule, no floor and no cap. They are
# strictly additive — they can only lengthen the query, so a narrow recorded
# search can never shrink the wrapper's own.
TERMS="$TITLE_TERMS"
while IFS= read -r tok; do
  [ -n "$tok" ] || continue
  contains_line "$TERMS" "$tok" && continue
  TERMS="$TERMS$tok
"
done <<EOF
$(printf '%s' "${SEARCHED_LINE#searched:}" | normalize_tokens)
EOF

# ── Independent duplicate query (feature design §5 step 3) ──────────────────
# One query per term: `--search` ANDs the terms inside a single argument, so a
# joined term string collapses to near-zero results and the layer would
# under-block by construction. `--state all`: the observed failure searched open
# issues only.
CANDIDATES=""
while IFS= read -r term; do
  [ -n "$term" ] || continue
  # shellcheck disable=SC2086  # GH_REPO_ARGS is a deliberate two-token split
  if ! rows="$(gh issue list $GH_REPO_ARGS --state all --limit "$PAGE_LIMIT" --json number,title,state --search "$term" 2>/dev/null)"; then
    echo "refuse: 'gh issue list --search $term' failed — the duplicate query could not be completed" >&2
    exit 65
  fi
  count="$(printf '%s' "$rows" | jq 'length')"
  # Truncation is fail-closed: a full page means the candidate set for this term
  # is provably incomplete, which would make the disposition invariant below
  # pass vacuously — the under-block harm reached through the mechanism meant to
  # prevent it.
  if [ "$count" -ge "$PAGE_LIMIT" ]; then
    echo "refuse: the query for term '$term' returned its full page of $PAGE_LIMIT results, so its candidate set cannot be proven complete" >&2
    exit 65
  fi
  CANDIDATES="$CANDIDATES$(printf '%s' "$rows" | jq -r '.[] | "\(.number)\t\(.title)"')
"
done <<EOF
$TERMS
EOF

# ── Candidate-disposition invariant (feature design §5 step 4) ──────────────
# Every issue number the wrapper's own query returned must already appear as a
# dispositioned row in the draft. This is the step that does not trust "I
# checked": it compares the agent's recorded check against a query the agent did
# not author. It stays a mechanical set comparison — whether a disposition is
# CORRECT is the operator's judgment at layer three, never the wrapper's.
DISPOSITIONED="$(printf '%s\n' "$DUPCHECK" | grep -v '^searched:' | grep -oE '#[0-9]+' | tr -d '#' | sort -u || true)"

UNDISPOSITIONED=""
while IFS="$(printf '\t')" read -r num title; do
  [ -n "$num" ] || continue
  if ! printf '%s\n' "$DISPOSITIONED" | grep -qxF "$num"; then
    case "
$UNDISPOSITIONED" in *"
#$num "*) continue ;; esac
    UNDISPOSITIONED="$UNDISPOSITIONED
#$num $title"
  fi
done <<EOF
$CANDIDATES
EOF

if [ -n "$UNDISPOSITIONED" ]; then
  echo "refuse: the wrapper's own query returned issue(s) the draft does not disposition — add a '#<number> — <disposition>' row for each under '## Duplicate check', or retitle:" >&2
  printf '%s\n' "$UNDISPOSITIONED" | grep -v '^$' | sed 's/^/  /' >&2
  exit 65
fi

# ── Creation (feature design §5 steps 5-6) ──────────────────────────────────
if [ "$DRY_RUN" = 1 ]; then
  echo "dry-run: every check passed for '$TITLE' — no issue created, $DRAFT_PATH left in place"
  exit 0
fi

BODY_FILE="$(mktemp)"
trap 'rm -f "$BODY_FILE"' EXIT
printf '%s\n' "$BODY" > "$BODY_FILE"

# The payload is bound to the draft at both arguments and carries nothing else
# from it: the title is the `## Title` line byte-for-byte and the body file holds
# the `## Body` section byte-for-byte, so `## Grounds` and `## Duplicate check`
# never reach the tracker.
# shellcheck disable=SC2086  # GH_REPO_ARGS is a deliberate two-token split
if URL="$(gh issue create $GH_REPO_ARGS --title "$TITLE" --body-file "$BODY_FILE")"; then
  :
else
  rc=$?
  echo "refuse: 'gh issue create' exited $rc — $DRAFT_PATH left in place" >&2
  exit "$rc"
fi
echo "$URL"

# The rename is a consequence of creation, never of intent to create. A URL from
# which no trailing number parses is a failed bind: leave the draft alone rather
# than renaming it to a guessed number.
NUMBER="${URL##*/}"
case "$NUMBER" in
  '' | *[!0-9]*)
    echo "refuse: no issue number parses from the URL gh returned ('$URL') — $DRAFT_PATH left in place rather than renamed to a guess" >&2
    exit 70 ;;
esac

RECORD="$AUTOFLOW_DIR/issue-${NUMBER}-proposal.md"
if ! mv "$DRAFT_PATH" "$RECORD"; then
  echo "warn: issue #$NUMBER was created but $DRAFT_PATH could not be renamed to $RECORD" >&2
  exit 70
fi
echo "proposal record: $RECORD"
exit 0
