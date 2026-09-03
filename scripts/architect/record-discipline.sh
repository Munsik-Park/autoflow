#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# record-discipline.sh — mechanical check of the ARCHITECT Record rules over
# the design documents (docs/autoflow-guide.md > ARCHITECT > Record rules)
# =============================================================================
# Issue #166. The rule "the design documents carry only the current design —
# no round history, no copy of the register, no measurement or command-output
# transcription" existed only as a prompt sentence (RECORD_DISCIPLINE_RULE in
# .claude/workflows/architect-deliberation.js) and had no checker. #595 cycle 1
# measured the residue that sentence left behind: a `## 5. Register — …`
# section of 387 lines (30% of the verification design) duplicating the
# register the script already holds, 12 "re-checked this round"-class phrases,
# 28 "Measured" narratives, and four turns spent clearing them by hand.
#
# This script is that checker. It reads meaning nowhere: each pattern below is
# a fixed grammar for one Record-rules bullet, and a hit is reported with its
# file, line and pattern name so the writer can clear it. A hit is a candidate
# for the writer's judgment where the document's subject is the deliberation
# itself (a design that legitimately says "turn 3"); everywhere else it is
# residue. Enforcement is a separate decision, which issue #166 leaves open:
# the facilitation prompts instruct a turn that WROTE or EDITED a document to
# run the check and clear its own hits before returning, and the orchestrator
# runs it after a CONVERGED return as an advisory beside the artifact-existence
# check. Nothing gates on it.
#
# Usage:
#   record-discipline.sh check <design-doc> [<design-doc> ...]
#
# stdout: one `<file>:<line>: <pattern>: <text>` line per hit, then a summary
#         line `record-discipline: clean` or `record-discipline: <N> hit(s)`.
# Exit:   0 clean | 1 at least one hit | 2 usage (no subcommand, no file, or a
#         named file missing / unreadable — reported on stderr, nothing checked)
# =============================================================================

set -uo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  record-discipline.sh check <design-doc> [<design-doc> ...]
USAGE
}

# Pattern table — `<name>|<flags>|<ERE>`. `flags` is `i` (case-insensitive) or
# `-`. No `\b`: written with explicit non-word classes so BSD and GNU grep read
# the same grammar.
#   register-section  a heading naming the register — the register is the
#                     script's (Record rules > "The register is the durable
#                     channel"), and a copy inside the document is the 30%
#                     #595 measured.
#   round-history     deliberation self-reference — "this round", "re-checked",
#                     "in turn 4" (Record rules > "no round history").
#   measurement-log   a `Measured` label opening a line or bullet — the
#                     transcription form #595 counted 28 times (Record rules >
#                     "No transcription").
#   command-output    a suite runner result line or a jest / pytest summary
#                     pasted verbatim (the same bullet).
PATTERNS='register-section|i|^#{1,6}[[:space:]].*(^|[^[:alnum:]_])register([^[:alnum:]_]|$)
round-history|i|(^|[^[:alnum:]_])(this|last|previous|prior|earlier|next)[[:space:]]+(round|turn)([^[:alnum:]_]|$)
round-history|i|(^|[^[:alnum:]_])re-?checked([^[:alnum:]_]|$)
round-history|i|(^|[^[:alnum:]_])(in|at|since|after|during|before)[[:space:]]+(round|turn)[[:space:]]+[0-9]+([^[:alnum:]_]|$)
measurement-log|-|^[[:space:]]*([-*+]|[0-9]+\.)?[[:space:]]*(\*\*|_)?Measured(\*\*|_)?[[:space:]]*(:|—|-)
command-output|-|^[[:space:]]*(PASS|FAIL|TIMEOUT):[[:space:]]
command-output|-|(^|[^[:alnum:]_])Tests:[[:space:]]+[0-9]+[[:space:]]+(passed|failed)
command-output|-|(^|[^[:alnum:]_])[0-9]+[[:space:]]+(passed|failed),[[:space:]]+[0-9]+[[:space:]]+total([^[:alnum:]_]|$)'

cmd_check() {
  if [ $# -lt 1 ]; then
    usage
    return 2
  fi
  local f
  for f in "$@"; do
    if [ ! -f "$f" ] || [ ! -r "$f" ]; then
      echo "record-discipline: not a readable file: $f" >&2
      return 2
    fi
  done
  # One report per (file, line, pattern name): a line matching two grammars of
  # the same bullet is one hit to clear, not two.
  local hits=0 name flags re line seen=""
  for f in "$@"; do
    while IFS='|' read -r name flags re; do
      [ -n "$name" ] || continue
      local opt="-n -E"
      [ "$flags" = "i" ] && opt="$opt -i"
      # shellcheck disable=SC2086
      while IFS= read -r line; do
        [ -n "$line" ] || continue
        case "$seen" in *"|$f:${line%%:*}:$name|"*) continue ;; esac
        seen="$seen|$f:${line%%:*}:$name|"
        printf '%s:%s: %s: %s\n' "$f" "${line%%:*}" "$name" "${line#*:}"
        hits=$((hits + 1))
      done < <(grep $opt -e "$re" "$f" 2>/dev/null || true)
    done <<< "$PATTERNS"
  done
  if [ "$hits" = "0" ]; then
    echo "record-discipline: clean"
    return 0
  fi
  echo "record-discipline: $hits hit(s)"
  return 1
}

case "${1:-}" in
  check) shift; cmd_check "$@" ;;
  *) usage; exit 2 ;;
esac
