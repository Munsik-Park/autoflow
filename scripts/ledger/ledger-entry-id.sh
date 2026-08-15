#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Decision-ledger entry identifier: allocation (`next`) and detection (`check`)
# =============================================================================
# The decision ledger (.autoflow/issue-{N}-ledger.md, CLAUDE.md > Decision
# Ledger) is append-only and written by two writers that cannot see each
# other's in-flight state — the orchestrator and its facilitator delegate.
# Without an issuance protocol both writers pick the "next" serial from their
# own memory of the file, so two entries collide on one identifier and every
# later citation of that identifier is ambiguous.
#
# This script is that protocol. It holds no state of its own: `next` derives
# the identifier from the file on disk at call time, so a writer that calls it
# immediately before each append can never collide with a writer that appended
# in between.
#
# Usage:
#   ledger-entry-id.sh next  <ledger-path> <namespace>   -> prints <NS><serial>
#   ledger-entry-id.sh check <ledger-path>               -> reports defects
#
# Namespaces (CLAUDE.md > Decision Ledger — the single documentary home of the
# writer -> namespace mapping): `O` = orchestrator, `F` = facilitator delegate.
# `E` is the pre-protocol legacy namespace: readable, never issuable.
#
# Exit codes:
#   next   0 = identifier printed on stdout | 2 = usage / unissuable namespace
#   check  0 = clean | 1 = defect found (reported on stderr) | 2 = usage
# `check` separates 1 from 2 so a caller can distinguish "the ledger has a
# defect" from "I was called wrong" — the hook's advisory step relies on it.
# =============================================================================

set -uo pipefail

ISSUABLE_NAMESPACES="O F"

usage() {
  cat >&2 <<'EOF'
Usage:
  ledger-entry-id.sh next  <ledger-path> <namespace>
  ledger-entry-id.sh check <ledger-path>

Namespaces issuable by `next`: O (orchestrator), F (facilitator delegate).
E is legacy — readable by `check`, never issued.
EOF
}

# Heading grammar shared by both subcommands: a settled-decision entry is a
# LEVEL-2 heading `## <NS><serial> — <title> (cycle <C>, <PHASE>)`. Level-3
# headings are record entries (green-tree, green-tree-use, verify-detection)
# and carry no identifier by design, so both subcommands ignore them.

# next <ledger-path> <namespace>
cmd_next() {
  local file="${1:-}" ns="${2:-}" max
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

  # A ledger that does not exist yet starts its own namespace at 1. This is the
  # first-append case, not an error: the writer creates the file with its
  # header and appends <NS>1.
  if [ ! -f "$file" ]; then
    printf '%s1\n' "$ns"
    return 0
  fi

  # Highest serial ALREADY IN THE FILE, within this namespace only. Namespace
  # isolation is what lets the two writers allocate concurrently: an F append
  # never moves O's counter, so neither writer's allocation depends on the
  # other's timing.
  max=$(awk -v ns="$ns" '
    match($0 " ", "^## " ns "[0-9]+ ") {
      id = substr($0, 4); sub(/ .*$/, "", id)
      n = substr(id, 2) + 0
      if (n > m) m = n
    }
    END { print m + 0 }
  ' "$file")

  printf '%s%d\n' "$ns" "$((max + 1))"
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
      if (match($0 " ", /^## [EOF][0-9]+ /)) {
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
  # Exactly one ledger, by design. Every caller — the hook's advisory step and
  # the facilitator prompts — passes a single path, and an aggregate scan would
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
