#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# verification-layer-check.sh — one device, two outputs, over a cycle's
# verification design.
# =============================================================================
# ADR-0024 D1 splits every verification into two layers and reads the layer off
# the `Type` cell of the verification design's acceptance-criteria table: a cell
# carrying `standing: <token>` is standing, a cell carrying no token is `cycle`.
# The `standing` category list is CLOSED — "a row that names a token outside the
# list is a layer violation … categories are extended by revising this ADR,
# never by describing a new one in a row".
#
# ARM A — CLOSED-LIST TOKEN MEMBERSHIP. A set relation over recorded text, with
# no judgment in it, so this arm owns a verdict and may FAIL. It binds a
# `manual / standing:` scenario exactly as it binds a test: D1 applies the
# criterion uniformly, "since a committed scenario file is a repository asset
# that every later cycle enumerates".
#
# ARM B — ROW-TO-ASSET PAIRING. It only REPORTS. The acceptance-criteria table's
# columns name no asset path, so a check that must INFER the row -> asset link
# owns no failure verdict; GATE:QUALITY, which reads the design and the diff
# together, does. The two arms are asymmetric by design and the exit status is
# arm A's alone — a run over a populated cycle-layer store and a run over an
# empty one answer identically.
#
# THE TOKEN LIST IS THIS FILE'S AND THE ADR'S, and they must agree: that
# agreement is itself a standing verification
# (tests/test-verification-layer-token-set.sh), asserted in both directions and
# then driven behaviourally, so `--list-tokens` cannot become a decorative list.
#
# Usage:
#   bash scripts/gate/verification-layer-check.sh <verification-design.md>
#   bash scripts/gate/verification-layer-check.sh --list-tokens
#
# Exit: 0 every `standing:` token in the document is in the closed list
#       1 at least one is not — the token and its row are both named
#       2 the document could not be read (absent, unreadable, or carrying no
#         acceptance-criteria table). A not-run is never rendered as a pass
#         (ADR-0024 D1).
# =============================================================================

set -uo pipefail

# ADR-0024 D1 > "Closed `standing` categories" — one token per line, in the
# ADR's own order. Revising this list without revising that table is the defect
# tests/test-verification-layer-token-set.sh exists to catch.
STANDING_TOKENS=(packaging manifest target-runtime cross-file)

if [ "$#" -ne 1 ]; then
  echo "verification-layer-check: usage: verification-layer-check.sh <verification-design.md> | --list-tokens" >&2
  exit 2
fi

if [ "$1" = "--list-tokens" ]; then
  printf '%s\n' "${STANDING_TOKENS[@]}"
  exit 0
fi

DESIGN="$1"
if [ ! -f "$DESIGN" ] || [ ! -r "$DESIGN" ]; then
  echo "verification-layer-check: cannot read the verification design: $DESIGN" >&2
  echo "  Unanswerable is reported as unanswerable — a silent 0 would be a pass over a document that was never opened." >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# TABLE PARSE. The table is located by its own header row — the one carrying
# both an `Issue AC` and a `Type` cell — rather than by a section heading: the
# heading is prose that a design may word differently, while the column names
# are the declaration site D1 names.
#
# Column indices are derived from that header, never assumed, so a table that
# gains or reorders a column keeps answering about the right cell.
# ---------------------------------------------------------------------------
ROWS="$(awk -F'|' '
  function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
  !hdr {
    if ($0 !~ /^\|/) next
    for (i = 2; i < NF; i++) {
      c = trim($i)
      if (c == "Issue AC") ac = i - 1
      if (c == "Type")     ty = i - 1
    }
    if (ac && ty) { hdr = 1 }
    next
  }
  {
    if ($0 !~ /^\|/) { if (seen) exit; else next }
    a = trim($(ac + 1)); t = trim($(ty + 1))
    if (a ~ /^-+$/ || t ~ /^-+$/) next          # the header separator row
    seen = 1
    printf "%s\t%s\n", a, t
  }
' "$DESIGN")"

if [ -z "$ROWS" ]; then
  echo "verification-layer-check: $DESIGN carries no acceptance-criteria table (no header row declaring both 'Issue AC' and 'Type') — nothing was checked" >&2
  echo "  The layer is read from the Type cell (ADR-0024 D1). With no such column there is no declaration to read, which is unanswerable rather than clean." >&2
  exit 2
fi

token_is_closed() {
  local t
  for t in "${STANDING_TOKENS[@]}"; do [ "$t" = "$1" ] && return 0; done
  return 1
}

# ---------------------------------------------------------------------------
# ARM A — closed-list membership. Decides the exit status.
# ---------------------------------------------------------------------------
VIOLATIONS=0
CYCLE_ROWS=()
STANDING_ROWS=0
echo "verification-layer-check: $DESIGN"
while IFS=$'\t' read -r ac type; do
  bare=""
  [ -n "$type" ] || continue
  case "$type" in
    *standing:*)
      tok="${type#*standing:}"
      tok="$(printf '%s' "$tok" | sed -E 's/^[[:space:]]+//; s/[[:space:]].*$//; s/`//g')"
      STANDING_ROWS=$((STANDING_ROWS + 1))
      if token_is_closed "$tok"; then
        echo "  standing  $ac  token '$tok'"
      else
        echo "  VIOLATION $ac  token '$tok' is outside ADR-0024 D1's closed standing list (${STANDING_TOKENS[*]})"
        VIOLATIONS=$((VIOLATIONS + 1))
      fi
      ;;
    *)
      # `existing-coverage` and `none` carry no layer of their own: D1 records
      # that such a row "adds no asset" and that its layer "was decided when it
      # was authored", so classifying it `cycle` would invent a cycle-layer
      # asset for it and make arm B report a pairing that was never owed.
      bare="$(printf '%s' "$type" | tr -d '`' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
      case "$bare" in
        existing-coverage|none|-|—)
          echo "  no-layer  $ac  '$bare' adds no asset — its layer was decided where it was authored"
          ;;
        *)
          echo "  cycle     $ac  '$bare' names no standing token — cycle by D1's default"
          CYCLE_ROWS+=("$ac|$bare")
          ;;
      esac
      ;;
  esac
done <<< "$ROWS"

# ---------------------------------------------------------------------------
# ARM B — the row-to-asset pairing. REPORTS ONLY; the exit status below never
# reads it. The store is derived from the design's own file name, because the
# table's columns carry no asset path — which is precisely why the pairing
# verdict stays with GATE:QUALITY rather than being taken here.
# ---------------------------------------------------------------------------
base="${DESIGN##*/}"
dir="${DESIGN%/*}"; [ "$dir" = "$DESIGN" ] && dir="."
issue="$(printf '%s' "$base" | sed -nE 's/^issue-([0-9]+)-.*$/\1/p')"
echo "  --- cycle-layer pairing (report only; the pairing verdict is GATE:QUALITY's) ---"
if [ -z "$issue" ]; then
  echo "  no issue number in the design's file name ($base) — the cycle-layer store cannot be located, so no pairing is reported"
elif [ "${#CYCLE_ROWS[@]}" -eq 0 ]; then
  echo "  no cycle-layer row in this design; the store issue-$issue-local is not consulted"
else
  store="$dir/issue-$issue-local"
  for row in "${CYCLE_ROWS[@]}"; do
    ac="${row%%|*}"; type="${row#*|}"
    if [ -d "$store" ]; then
      n="$(find "$store" -type f 2>/dev/null | grep -c . || true)"
      echo "  $ac ($type) — cycle-layer store issue-$issue-local holds $n asset(s)"
    else
      echo "  $ac ($type) — cycle-layer store issue-$issue-local is absent"
    fi
  done
fi

# ---------------------------------------------------------------------------
if [ "$VIOLATIONS" -eq 0 ]; then
  echo "verification-layer-check: OK — $STANDING_ROWS standing row(s), ${#CYCLE_ROWS[@]} cycle row(s), no token outside ADR-0024 D1's closed list"
  exit 0
fi
echo "verification-layer-check: $VIOLATIONS layer violation(s)"
echo "  The standing category list is closed: a category is added by revising ADR-0024 D1, never by describing a new one in a row."
exit 1
