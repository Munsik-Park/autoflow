#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: tests/manual/ docs/doc-invariant-registry.md
# =============================================================================
# Test: tests/manual/ scenario-document retirement — Issue #76 AC-c-1
# =============================================================================
# .autoflow/issue-76-verification-design.md > AC-c-1: every retired scenario
# document is deleted with a §5 disposition row, and no workflow `paths:`
# entry still names a deleted file. Retired/retained lists are FROZEN at
# design time (.autoflow/issue-76-feature-design.md > `manual-doc-closure`)
# and asserted against as literals — this suite does not recompute the
# dependency rule (`retirement-partition-tautology`, CLOSED).
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANUAL_DIR="$PROJECT_ROOT/tests/manual"
DISPOSITION_DOC="$PROJECT_ROOT/docs/doc-invariant-registry.md"

RETIRED=(
  issue-26 issue-43 issue-844 issue-949 issue-951 issue-952 issue-973 issue-979
)
RETAINED=(
  issue-27 issue-42 issue-51 issue-52 issue-55 issue-56 issue-59 issue-62
  issue-67 issue-71 issue-795 issue-798 issue-799 issue-800 issue-846
  issue-847 issue-848 issue-985
)

PASS=0; FAIL=0; TESTS=0

assert_true() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if eval "$condition"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Issue #76 — manual-scenario-document retirement (AC-c-1) ==="

for name in "${RETIRED[@]}"; do
  # Resolve the actual filename (naming is <name>-manual-scenarios.md, but
  # not asserted to be exact — glob to tolerate the doc's own naming).
  match="$(find "$MANUAL_DIR" -maxdepth 1 -iname "${name}-manual-scenarios.md" 2>/dev/null | head -1)"
  assert_true "AC-c-1: retired scenario document is absent from tests/manual/ — $name" \
    "[ -z '$match' ]"
  assert_true "AC-c-1: retired scenario document has no dangling paths: entry in any workflow — $name" \
    "! grep -rlq \"${name}-manual-scenarios\" '$PROJECT_ROOT/.github/workflows' 2>/dev/null"
  # GATE:QUALITY FAIL #5 (ledger E14): a bare `grep -qi "$name"` matches any
  # incidental mention of the issue number anywhere in the document (a
  # design-rationale sentence, a cross-reference in an unrelated row) — not
  # that a §6 disposition ROW actually retires this document. Anchored to
  # the row's own shape: a `|`-led table row that names both
  # `tests/manual/` and the backtick-quoted issue token, and carries a bold
  # disposition label (`**dropped …**` / `**retired …**` / etc.) in the
  # same row.
  row_pattern="^\|.*tests/manual/.*\`${name}\`.*\*\*[A-Za-z].*\*\*"
  assert_true "AC-c-1: retired scenario document has a §6 disposition ROW naming it (not an incidental mention) — $name" \
    "[ -f '$DISPOSITION_DOC' ] && grep -qE \"$row_pattern\" '$DISPOSITION_DOC' 2>/dev/null"
done

for name in "${RETAINED[@]}"; do
  match="$(find "$MANUAL_DIR" -maxdepth 1 -iname "${name}-manual-scenarios.md" 2>/dev/null | head -1)"
  assert_true "AC-c-1: retained scenario document is still present — $name" \
    "[ -n '$match' ]"
done

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
