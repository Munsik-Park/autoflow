#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# check-tests-tree-hygiene.sh — standing lint: no file under tests/** carries an
# embedded NUL byte.
# =============================================================================
# Promoted from the retired issue-#75 suite's NUL-byte-absence check, which
# `docs/doc-invariant-registry.md` §5 routed to #76 as a promotion candidate.
# The condition is permanent and its subject is a TREE rather than a named
# document, so the doc-invariant registry cannot hold it — a registry entry's
# `file` is one path.
#
# The byte test is carried verbatim from the retired check, including its
# deliberate avoidance of `grep -P`: `grep -aP '\x00'` exits 2 on the BSD grep
# of a macOS host, and a bare `! grep -aP …` reads that exit 2 as "no match",
# manufacturing a vacuous PASS. The portable form used here strips NUL bytes
# with `LC_ALL=C tr -d '\000'` and compares the result against the original —
# a file is clean exactly when the two are byte-identical.
#
# Usage:
#   bash scripts/test/check-tests-tree-hygiene.sh [--root <dir>]
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root)      ROOT="${2:-}"; shift ;;
    *)           echo "check-tests-tree-hygiene: unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done
ROOT="${ROOT:-$DEFAULT_ROOT}"

# has_nul <file> -> 0 when the file carries an embedded NUL byte.
# Fails loud (exit 3) when the byte test's own tools are unusable, rather than
# reading a tool error as "no match" — that inversion is the vacuous-PASS
# mechanism this lint exists to keep out of the tree.
has_nul() {
  local file="$1" stripped rc
  stripped="$(mktemp)" || { echo "check-tests-tree-hygiene: mktemp unusable" >&2; exit 3; }
  if ! LC_ALL=C tr -d '\000' < "$file" > "$stripped" 2>/dev/null; then
    rm -f "$stripped"
    echo "check-tests-tree-hygiene: byte test unusable — 'tr' failed on $file" >&2
    exit 3
  fi
  cmp -s "$stripped" "$file"; rc=$?
  rm -f "$stripped"
  if [ "$rc" -gt 1 ]; then
    echo "check-tests-tree-hygiene: byte test unusable — 'cmp' errored on $file" >&2
    exit 3
  fi
  [ "$rc" -eq 1 ]
}

# scan_tree <root> — prints one line per offending file; returns non-zero when
# the offending set is non-empty.
scan_tree() {
  local root="$1" found=0 f
  [ -d "$root/tests" ] || return 0
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    if has_nul "$f"; then
      echo "  NUL byte in ${f#"$root"/}"
      found=1
    fi
  done < <(find "$root/tests" -type f | sort)
  [ "$found" -eq 0 ]
}

if scan_tree "$ROOT"; then
  echo "check-tests-tree-hygiene: OK — no file under $ROOT/tests carries an embedded NUL byte"
  exit 0
fi
echo "check-tests-tree-hygiene: offending file(s) above carry an embedded NUL byte"
exit 1
