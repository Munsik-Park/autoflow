#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Decision-ledger entry identifier: allocation (`next`) and detection (`check`)
# =============================================================================
# The decision ledger (<attempt-dir>/issue-{N}-ledger.md, the attempt's record directory — docs/core.md > Decision
# Ledger) is append-only and written by writers that cannot see each
# other's in-flight state — the orchestrator and the advisor.
# Without an issuance protocol each writer picks the "next" serial from its
# own memory of the file, so two entries collide on one identifier and every
# later citation of that identifier is ambiguous.
#
# This script is that protocol. `next` derives the identifier from the file on
# disk at call time and RESERVES it before printing it, so two writers of one
# namespace that both call `next` before either appends — two advisors spawned
# together (issue #448) — still receive different identifiers. A reservation is
# an empty directory `<ledger-path minus .md>.ids/<NS><serial>` beside the
# ledger, created with `mkdir`, which succeeds for exactly one caller; the
# store holds nothing else, and the ledger file itself is never touched here.
# A reserved identifier that is never appended (the append denied, the writer
# stopped) leaves a gap in the serial; a gap is not a defect, and `check` does
# not report one.
#
# Usage:
#   ledger-entry-id.sh next  <ledger-path> <namespace>   -> prints <NS><serial>
#   ledger-entry-id.sh check <ledger-path>               -> reports defects
#
# Namespaces (docs/decision-ledger.md > Entry identifier — the single documentary
# home of the writer -> namespace mapping): `O` = orchestrator, `A` = advisor.
# `E` and `F` are legacy namespaces: readable, never issuable.
#
# Exit codes:
#   next   0 = identifier printed on stdout | 1 = no identifier could be
#          reserved (the store is not writable) | 2 = usage / unissuable namespace
#   check  0 = clean | 1 = defect found (reported on stderr) | 2 = usage
# `check` separates 1 from 2 so a caller can distinguish "the ledger has a
# defect" from "I was called wrong" — the hook's advisory step relies on it.
# =============================================================================

set -uo pipefail

ISSUABLE_NAMESPACES="O A"

usage() {
  cat >&2 <<'EOF'
Usage:
  ledger-entry-id.sh next  <ledger-path> <namespace>
  ledger-entry-id.sh check <ledger-path>

Namespaces issuable by `next`: O (orchestrator), A (advisor).
E and F are legacy — readable by `check`, never issued.
EOF
}

# Heading grammar shared by both subcommands: a settled-decision entry is a
# LEVEL-2 heading `## <NS><serial> — <title> (cycle <C>, <PHASE>)`. Level-3
# headings are record entries (preflight-plugin, preflight-local-checks,
# preflight-review-config) and carry no identifier by design, so both
# subcommands ignore them.

# next <ledger-path> <namespace>
cmd_next() {
  local file="${1:-}" ns="${2:-}" store max res n cand tries
  if [ -z "$file" ] || [ -z "$ns" ]; then
    usage
    return 2
  fi
  case " $ISSUABLE_NAMESPACES " in
    *" $ns "*) ;;
    *)
      echo "ledger-entry-id: namespace '$ns' is not issuable (issuable: $ISSUABLE_NAMESPACES)" >&2
      return 2
      ;;
  esac

  store="${file%.md}.ids"
  if ! mkdir -p "$store" 2>/dev/null; then
    echo "ledger-entry-id: cannot create the reservation store: $store" >&2
    return 1
  fi

  # Highest serial ALREADY IN THE FILE, within this namespace only. Namespace
  # isolation keeps an A append from moving O's counter. A ledger that does not
  # exist yet counts 0, so its first entry is <NS>1 — the first-append case,
  # not an error: the writer creates the file with its header and appends it.
  max=0
  if [ -f "$file" ]; then
    max=$(awk -v ns="$ns" '
      match($0 " ", "^## " ns "[0-9]+ ") {
        id = substr($0, 4, RLENGTH - 4)
        n = substr(id, length(ns) + 1) + 0
        if (n > m) m = n
      }
      END { print m + 0 }
    ' "$file")
  fi

  # Highest serial already reserved. A reservation not yet appended is what the
  # file cannot show; counting it is what keeps a concurrent writer from
  # re-deriving the same serial. A ledger with no store (written before
  # reservations) is counted from the file alone.
  for res in "$store/$ns"[0-9]*; do
    [ -d "$res" ] || continue
    n=${res##*/"$ns"}
    case "$n" in *[!0-9]*) continue ;; esac
    n=$((10#$n))
    [ "$n" -gt "$max" ] && max=$n
  done

  # mkdir is the atomic step: it succeeds for exactly one caller, so a writer
  # that lost the race moves on to the next serial instead of sharing it.
  cand=$((max + 1))
  tries=0
  while ! mkdir "$store/$ns$cand" 2>/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -ge 1000 ]; then
      echo "ledger-entry-id: no identifier could be reserved in $store" >&2
      return 1
    fi
    cand=$((cand + 1))
  done

  printf '%s%d\n' "$ns" "$cand"
}

# check_one <ledger-path> — defect lines on stdout (routed to stderr by the
# caller, so a clean run leaves both streams empty), exit 1 if any
check_one() {
  awk '
    # Heading text is echoed back to a caller that may surface it in a hook
    # warning line, so it is bounded and stripped of control characters here,
    # at the single point that emits it.
    function sanitize(s) {
      gsub(/[[:cntrl:]]/, " ", s)
      if (length(s) > 120) s = substr(s, 1, 117) "..."
      return s
    }
    /^## / {
      if (match($0 " ", /^## [EOFA][0-9]+ /)) {
        id = substr($0, 4); sub(/ .*$/, "", id)
        if (id in lines) { lines[id] = lines[id] "," NR }
        else { lines[id] = NR; order[++n] = id }
      } else {
        printf "unidentified-entry: line %d: %s\n", NR, sanitize($0)
        bad = 1
      }
    }
    END {
      for (i = 1; i <= n; i++) {
        id = order[i]
        if (lines[id] ~ /,/) {
          printf "duplicate-id: %s (lines %s)\n", id, lines[id]
          bad = 1
        }
      }
      exit bad ? 1 : 0
    }
  ' "$1"
}

# check <ledger-path>
cmd_check() {
  local file="${1:-}"
  # Exactly one ledger, by design. Every caller — the hook's advisory step, or
  # a writer that runs it by hand — passes a single path, and an aggregate scan would
  # blur which ledger a defect line belongs to, since the line names a number
  # inside a file it does not identify. A second argument is therefore a usage
  # error with the same disposition as none at all, not a wider scan.
  if [ "$#" -ne 1 ] || [ -z "$file" ]; then
    usage
    return 2
  fi
  if [ ! -f "$file" ]; then
    echo "ledger-entry-id: no such ledger: $file" >&2
    return 2
  fi
  check_one "$file" >&2
}

main() {
  local sub="${1:-}"
  [ "$#" -gt 0 ] && shift
  case "$sub" in
    next)  cmd_next "$@" ;;
    check) cmd_check "$@" ;;
    *)     usage; return 2 ;;
  esac
}

main "$@"
