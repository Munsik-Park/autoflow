#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# ARCHITECT relay transcript — header, brief, and decidable state (issue #179)
# =============================================================================
# The ARCHITECT deliberation is relayed by the orchestrator between two
# persistent participants (ADR-0023 D2): the Developer AI and the Test AI are
# spawned once per discussion and woken in alternation, and every turn is
# appended by its author to `.autoflow/issue-{N}-architect-transcript.md`.
# That file is the discussion's single record and the participants' shared
# memory. This script reads it and prints the state the orchestrator's
# procedure (docs/autoflow-guide.md > ARCHITECT) consumes: how many turns
# exist, whose turn is next, whether the discussion has ended — two
# consecutive turns marked `further: none` (issue #166, unchanged) — and which
# reports are present. It computes and never judges: no turn is read for its
# content, and no cap, threshold or verdict lives here.
#
# Usage:
#   relay-state.sh init  <transcript> <issue> [<brief>]  -> writes the header
#   relay-state.sh brief <transcript> <brief>            -> appends a Brief block
#   relay-state.sh state <transcript>                    -> prints key=value lines
#
# Transcript grammar. One block per turn, appended by the participant that
# wrote it, in this exact heading form (the marker is on the heading so a body
# that happens to contain the words is never mis-read):
#
#   ### Turn <n> — <Developer AI|Test AI> [further: <yes|none>]
#   <message>
#
# Turn 1 is the Developer AI's and sides alternate. After the discussion has
# ended, each participant appends one report section:
#
#   ## Report — <Developer AI|Test AI>
#
# A `### Brief` block — the orchestrator's preparation for a re-discussion —
# may sit between turns. It re-opens a discussion that had ended, so the end
# condition is evaluated over the turns written after the last brief; the turn
# numbering and the alternation continue across it.
#
# `state` prints, one per line:
#   turns=<n>                        turn blocks found
#   last=<dev|test|->                side of the last turn (`-` when none)
#   ended=<true|false>               the last two turns after the last brief both `further: none`
#   reports=<dev,test|dev|test|->    report sections present
#   reports_missing=<...|->          the complement of `reports` once ended, else `-`
#   next=<dev|test|report|record>    dev / test: the side that writes the next turn;
#                                    report: ended and no report yet;
#                                    record: ended and at least one report present
#
# Exit: 0 state printed | 1 transcript malformed (cause on stderr) | 2 usage
# =============================================================================

set -uo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  relay-state.sh init  <transcript> <issue> [<brief>]
  relay-state.sh brief <transcript> <brief>
  relay-state.sh state <transcript>
USAGE
  exit 2
}

# The topic, stated once (issue #166): the only per-run text, identical for
# every turn. The decision ledger's settled entries are part of the topic so a
# settled decision is read, not re-argued (CLAUDE.md > Decision Ledger). The
# orchestrator's brief, when given at init, is carried verbatim as part of it.
topic_text() {   # <issue> [<brief>]
  local issue="$1" brief="${2:-}"
  printf 'Issue #%s. Inputs: .autoflow/issue-%s-phase-a.md (code structure), .autoflow/issue-%s-phase-b.md (issue analysis and the acceptance-criteria table), any other .autoflow/issue-%s-*.md, and the decision ledger .autoflow/issue-%s-ledger.md if it exists — an entry there under authority "ARCHITECT agreed", "ARCHITECT mutual ACCEPT", "ARCHITECT rejected" or "operator decision" is settled and is reopened only on a fact verified now that was unavailable when it was written. Question: what is the feature design for this issue — files to change, API interface, data structures, dependencies — and how is each acceptance criterion verified?' \
    "$issue" "$issue" "$issue" "$issue" "$issue"
  if [ -n "$brief" ]; then
    printf '\n\nFrom the orchestrator: %s' "$brief"
  fi
  printf '\n'
}

cmd_init() {
  local t="$1" issue="$2" brief="${3:-}"
  case "$issue" in ''|*[!0-9]*) echo "relay-state: issue must be a number (got '$issue')" >&2; exit 2 ;; esac
  if [ -e "$t" ]; then
    echo "relay-state: $t already exists — the transcript is append-only and is never re-initialised" >&2
    exit 1
  fi
  {
    printf '# ARCHITECT transcript — issue #%s\n\n## Topic\n' "$issue"
    topic_text "$issue" "$brief"
    printf '\n## Transcript\n'
  } > "$t" || { echo "relay-state: cannot write $t" >&2; exit 1; }
  return 0
}

cmd_brief() {
  local t="$1" brief="$2"
  [ -f "$t" ] || { echo "relay-state: $t not found" >&2; exit 2; }
  [ -n "$brief" ] || { echo "relay-state: brief text is empty" >&2; exit 2; }
  grep -q '^## Transcript$' "$t" || { echo "relay-state: $t carries no '## Transcript' header (not an initialised transcript)" >&2; exit 1; }
  printf '\n### Brief\n%s\n' "$brief" >> "$t" || { echo "relay-state: cannot append to $t" >&2; exit 1; }
  return 0
}

# The parser. Plain awk over the heading lines only; bodies are skipped. Every
# defect is reported with its line number and fails the call, so the
# orchestrator repairs the transcript (re-wakes the author) instead of relaying
# on a mis-numbered record.
cmd_state() {
  local t="$1"
  [ -f "$t" ] || { echo "relay-state: $t not found" >&2; exit 2; }
  LC_ALL=C awk '
    function fail(msg) { printf("relay-state: line %d: %s\n", NR, msg) > "/dev/stderr"; bad = 1; exit 1 }
    BEGIN { turns = 0; last = "-"; pair = 0; ended = 0; rdev = 0; rtest = 0; intx = 0; inrep = 0 }
    /^## Transcript$/ { intx = 1; next }
    /^### Turn / {
      if (!intx) fail("turn heading before the \"## Transcript\" header")
      if (inrep) fail("turn heading after a report section")
      line = $0
      # ### Turn <n> — <side> [further: <yes|none>]   (the dash is U+2014, three bytes in C locale)
      if (line !~ /^### Turn [0-9]+ \xe2\x80\x94 (Developer AI|Test AI) \[further: (yes|none)\]$/) {
        fail("malformed turn heading: " line)
      }
      n = line; sub(/^### Turn /, "", n); sub(/ .*$/, "", n); n = n + 0
      side = (line ~ /Developer AI/) ? "dev" : "test"
      further = (line ~ /\[further: none\]$/) ? "none" : "yes"
      if (n != turns + 1) fail("turn " n " follows turn " turns " (turns must be consecutive from 1)")
      expect = (n % 2 == 1) ? "dev" : "test"
      if (side != expect) fail("turn " n " is written by the " (side == "dev" ? "Developer AI" : "Test AI") " but that turn belongs to the " (expect == "dev" ? "Developer AI" : "Test AI"))
      turns = n; last = side
      if (further == "none") { pair++ } else { pair = 0 }
      ended = (pair >= 2) ? 1 : 0
      next
    }
    /^### Brief$/ {
      if (!intx) fail("brief before the \"## Transcript\" header")
      if (inrep) fail("brief after a report section")
      pair = 0; ended = 0
      next
    }
    /^## Report \xe2\x80\x94 / {
      if (!ended) fail("report section before the discussion has ended")
      if ($0 ~ /^## Report \xe2\x80\x94 Developer AI$/) { if (rdev) fail("duplicate Developer AI report"); rdev = 1 }
      else if ($0 ~ /^## Report \xe2\x80\x94 Test AI$/) { if (rtest) fail("duplicate Test AI report"); rtest = 1 }
      else fail("malformed report heading: " $0)
      inrep = 1
      next
    }
    END {
      if (bad) exit 1
      if (!intx) { printf("relay-state: no \"## Transcript\" header\n") > "/dev/stderr"; exit 1 }
      reports = "-"; missing = "-"
      if (rdev && rtest) reports = "dev,test"
      else if (rdev) reports = "dev"
      else if (rtest) reports = "test"
      if (ended) {
        if (!rdev && !rtest) missing = "dev,test"
        else if (!rdev) missing = "dev"
        else if (!rtest) missing = "test"
      }
      if (!ended) nxt = (turns % 2 == 0) ? "dev" : "test"
      else if (!rdev && !rtest) nxt = "report"
      else nxt = "record"
      printf("turns=%d\nlast=%s\nended=%s\nreports=%s\nreports_missing=%s\nnext=%s\n", turns, last, ended ? "true" : "false", reports, missing, nxt)
    }
  ' "$t"
}

[ $# -ge 1 ] || usage
case "$1" in
  init)  { [ $# -eq 3 ] || [ $# -eq 4 ]; } || usage; cmd_init "$2" "$3" "${4:-}" ;;
  brief) [ $# -eq 3 ] || usage; cmd_brief "$2" "$3" ;;
  state) [ $# -eq 2 ] || usage; cmd_state "$2" ;;
  *) usage ;;
esac
