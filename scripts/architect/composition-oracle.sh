#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# scripts/architect/composition-oracle.sh — the composition-oracle T ∩ S classifier (issue #206)
#
# Usage: composition-oracle.sh <verification-design-file>
#
# Reads the latest `composition-oracle` block of one verification design and classifies its
# determination as exactly one of intersection / empty / unknown/error. It writes nothing: the
# recording role attaches this output — stdout and exit status, as the shell produced them — to
# the determination.
#
# The record grammar, the three outcomes with their exit statuses, and the reading rule are
# defined once, in docs/autoflow-guide.md > ARCHITECT > Output artifacts > Composition oracle.
# This script implements that clause and does not restate it. Two properties of the output are
# the script's own, and the clause relies on both:
#   - the `result:` line is printed last, immediately before the explicit exit, so a run that
#     fails earlier leaves no classifying line behind;
#   - every stdout line starts with a fixed `<field>:` word, so an attached output never parses
#     as a block, and a re-run over the recorded artifact reproduces it.

set -euo pipefail

STATUS_INTERSECTION=10
STATUS_EMPTY=11
STATUS_UNKNOWN=1

# unknown <cause> — the unknown/error outcome, for a cause found before the block is read.
unknown() {
  local cause="${1//$'\n'/ }"
  printf 'cause: %s\n' "${cause//$'\r'/ }"
  printf 'result: unknown/error\n'
  exit "$STATUS_UNKNOWN"
}

[ "$#" -eq 1 ] || unknown "usage: composition-oracle.sh <verification-design-file>"
file="$1"
[ -f "$file" ] || unknown "no regular file at $file"
[ -r "$file" ] || unknown "$file is not readable"

# First line: the outcome word. Remaining lines: the output fields, each with a fixed prefix.
verdict="$(LC_ALL=C awk '
  function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
  function fail(msg) {
    print "unknown"; print "evaluated: " where[nb]; print "cause: " msg
    exit
  }
  BEGIN { nb = 0; open = 0; round = "base" }
  {
    t = trim($0)
    if (open) {
      if (t == "```") { open = 0; next }
      n[nb]++; text[nb, n[nb]] = t; lineno[nb, n[nb]] = NR
      next
    }
    if ($0 ~ /^##[[:space:]]+Delta[[:space:]]/ && match($0, /round[[:space:]]+[0-9]+/)) {
      r = substr($0, RSTART, RLENGTH); sub(/^round[[:space:]]+/, "", r); round = "round " r
      next
    }
    if (t == "```composition-oracle") { nb++; open = 1; n[nb] = 0; where[nb] = round; start[nb] = NR }
  }
  END {
    if (nb == 0) { print "unknown"; print "cause: the file has no composition-oracle block"; exit }
    if (open) fail("the latest block, opened at line " start[nb] ", is never closed")
    cur = ""; nt = 0
    for (i = 1; i <= n[nb]; i++) {
      t = text[nb, i]; ln = lineno[nb, i]
      if (t == "") continue
      if (t ~ /^[TS]:/) {
        L = substr(t, 1, 1); rest = trim(substr(t, 3))
        if (L in state) fail("line " ln ": the " L " list is labelled twice")
        cur = L; count[L] = 0
        if (rest == "") { state[L] = "entries"; continue }
        p = index(rest, "|")
        if (rest ~ /^none([[:space:]]|[|]|$)/ && p > 0 && trim(substr(rest, 5, p - 5)) == "" && trim(substr(rest, p + 1)) != "") {
          state[L] = "none"; continue
        }
        fail("line " ln ": the " L " label is neither a bare label nor a none declaration with a one-line ground")
      }
      if (t == "-" || t ~ /^-[[:space:]]/) {
        if (cur == "") fail("line " ln ": an entry precedes the T and S labels")
        if (state[cur] == "none") fail("line " ln ": the " cur " list is declared none and also carries entries")
        e = trim(substr(t, 2)); p = index(e, "|")
        id = p ? trim(substr(e, 1, p - 1)) : e
        src = p ? trim(substr(e, p + 1)) : ""
        if (id == "") fail("line " ln ": a " cur " entry has no identifier")
        if (id ~ /[[:space:]]/) fail("line " ln ": a " cur " entry identifier contains whitespace")
        if (src == "") fail("line " ln ": a " cur " entry has no source")
        count[cur]++
        if (cur == "T") { if (!(id in inT)) { inT[id] = 1; order[++nt] = id } }
        else inS[id] = 1
        continue
      }
      fail("line " ln ": a line that is neither a T or S label nor an entry")
    }
    if (!("T" in state)) fail("the latest block has no T list")
    if (!("S" in state)) fail("the latest block has no S list")
    if (state["T"] == "entries" && count["T"] == 0) fail("the T list has no entries and no none declaration")
    if (state["S"] == "entries" && count["S"] == 0) fail("the S list has no entries and no none declaration")
    hits = ""
    for (k = 1; k <= nt; k++) if (order[k] in inS) hits = hits " " order[k]
    if (hits == "") { print "empty"; print "evaluated: " where[nb]; exit }
    print "intersection"; print "evaluated: " where[nb]; print "intersecting:" hits
  }
' < "$file")" || unknown "$file could not be read"

{ IFS= read -r kind; body="$(cat)"; } <<<"$verdict"
case "$kind" in
  intersection) status=$STATUS_INTERSECTION ;;
  empty)        status=$STATUS_EMPTY ;;
  unknown)      status=$STATUS_UNKNOWN; kind="unknown/error" ;;
  *)            unknown "the classifier produced no outcome" ;;
esac
printf '%s\n' "$body"
printf 'result: %s\n' "$kind"
exit "$status"
