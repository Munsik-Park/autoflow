#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: issue #73 — ADR-0017 Status transition (cycle-scoped, retired at the
# final commit before the DELIVER push — verification design §7)
# =============================================================================
# Verification design: .autoflow/issue-73-verification-design.md §1
# (AC-adr-status), §4 (*status-literal permanence*, *status value shape*).
# Feature design: .autoflow/issue-73-feature-design.md > adr-status-value.
#
# AC-adr-status is intentionally NOT a permanent registry entry: a permanent
# `Accepted` literal would freeze a reversal path this ADR itself records
# (registry entry `51-pilot-reversal`), and the Status vocabulary includes
# `Superseded`. This suite asserts the CURRENT landed value only, and is
# retired in this cycle's final commit together with its CI registration and
# its docs/doc-invariant-registry.md disposition row (verification design §7,
# three-part shape).
#
# What this suite checks that no other suite does:
#   - tests/test-issue-51-teammate-removal-verdict.sh AC1(c) only anchors the
#     `## Status` value to the closed four-value vocabulary
#     (Proposed|Accepted|Deprecated|Superseded) — it does not assert WHICH
#     member. AC1(d) there is branch-scoped to dev/*-issue-51* and inert here.
#   - docs/adr/README.md's Current Drafts row for ADR-0017 is not asserted by
#     any existing suite or registry entry.
#
# RED expectation (this commit — ADR Status still reads Proposed, README row
# still reads Proposed):
#   FAIL: AC-adr-status-value, AC-adr-status-attribution-line,
#         AC-adr-readme-cell, AC-adr-agreement
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ADR_REL="docs/adr/0017-teammate-removal-feasibility.md"
ADR="$PROJECT_ROOT/$ADR_REL"
ADR_README="$PROJECT_ROOT/docs/adr/README.md"

PASS=0; FAIL=0; TESTS=0

# assert_eq / assert_no_paren compare already-computed values directly via
# bash's own `[`/`case` builtins — no file-derived value is ever handed to
# `eval` or otherwise re-parsed as shell (AUDIT finding: a single quote in
# ADR/README content could break out of an eval'd condition string).
assert_eq() {                # desc actual expected
  local desc="$1" actual="$2" expected="$3"
  TESTS=$((TESTS + 1))
  if [ "$actual" = "$expected" ]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

assert_no_paren() {          # desc value
  local desc="$1" value="$2"
  TESTS=$((TESTS + 1))
  case "$value" in
    *'('*)
      echo "  FAIL: $desc"
      FAIL=$((FAIL + 1))
      ;;
    *)
      echo "  PASS: $desc"
      PASS=$((PASS + 1))
      ;;
  esac
}

# extract_section mirrors tests/run-doc-invariants.sh's own extractor
# (durable heading anchor, level-aware close, bare-`---` thematic-break
# terminator when no section_end is given) — same shape as
# tests/test-issue-51-teammate-removal-verdict.sh's copy.
extract_section() {          # heading_text file
  local heading="$1" file="$2"
  awk -v h="$heading" '
    function level(line,   n){ n=0; while(substr(line,n+1,1)=="#") n++; return n }
    !f && /^#{1,6} +/ {
      t=$0; sub(/^#{1,6} +/,"",t); sub(/[ \t]+$/,"",t)
      if (t==h) { f=1; L=level($0); next }
    }
    f {
      if (/^#{1,6} +/ && level($0)<=L)          { f=0; next }
      else if (/^---[ \t]*$/)                   { f=0; next }
      else print
    }
  ' "$file" 2>/dev/null
}

echo "=== issue #73 — ADR-0017 Status transition (Proposed -> Accepted) ==="

if [ ! -f "$ADR" ]; then
  echo "  FAIL: ADR-0017 not found at $ADR_REL"
  FAIL=$((FAIL + 1)); TESTS=$((TESTS + 1))
else
  STATUS_BODY="$(extract_section "Status" "$ADR")"
  # Non-blank lines of the ## Status section, in order.
  NONBLANK_LINES="$(printf '%s\n' "$STATUS_BODY" | grep -vE '^[[:space:]]*$')"
  STATUS_FIRST_LINE="$(printf '%s\n' "$NONBLANK_LINES" | head -1 | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"

  echo ""
  echo "--- AC-adr-status-value ---"
  assert_eq "AC-adr-status-value: '## Status' first non-blank line is exactly 'Accepted' (currently '$STATUS_FIRST_LINE')" \
    "$STATUS_FIRST_LINE" "Accepted"

  echo ""
  echo "--- AC-adr-status-attribution-line ---"
  # The design requires attribution (if any) on a FOLLOWING line, never
  # inline with the value — a same-line attribution (e.g. 'Accepted (owner
  # decision, 2026-08-10)') must fail AC-adr-status-value above, which it does
  # since that value would not equal 'Accepted' exactly.
  assert_no_paren "AC-adr-status-attribution-line: no inline attribution on the value line itself (first non-blank line contains no parenthesis)" \
    "$STATUS_FIRST_LINE"

  echo ""
  echo "--- AC-adr-readme-cell ---"
  README_ROW="$(grep -F '0017-teammate-removal-feasibility.md' "$ADR_README" | head -1)"
  README_STATUS_CELL="$(printf '%s' "$README_ROW" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3}')"
  assert_eq "AC-adr-readme-cell: docs/adr/README.md Current Drafts row Status cell reads 'Accepted' (currently '$README_STATUS_CELL')" \
    "$README_STATUS_CELL" "Accepted"

  echo ""
  echo "--- AC-adr-agreement ---"
  assert_eq "AC-adr-agreement: ADR '## Status' value and README Status cell agree (ADR='$STATUS_FIRST_LINE', README='$README_STATUS_CELL')" \
    "$STATUS_FIRST_LINE" "$README_STATUS_CELL"
fi

echo ""
echo "=== Summary: $PASS/$TESTS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
