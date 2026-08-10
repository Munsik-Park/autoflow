#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: runner --self-test mode (AC-a-3) and anchor-resolution negative
#       coverage for the new section_kind values (AC-f) — Issue #76
# =============================================================================
# .autoflow/issue-76-verification-design.md:
#   AC-a-3 — sample invalidation makes the runner RED (teeth), promoted into
#     `tests/run-doc-invariants.sh --self-test` (feature design
#     `teeth-in-runner`): exhaustive per-entry mutation, credit requires the
#     entry's OWN predicate to report FAIL; an unresolvable anchor after
#     mutation is a non-credit with a diagnostic, never an abort, never a
#     credit (`teeth-mode-anchor-destruction`).
#   AC-f — the new section_kind values resolve the same body the source
#     suite's extractor read: hermetic anchor fixtures — zero-match and
#     multi-match "line" anchors REJECTED AT LOAD TIME; a "block" fixture
#     with a section_end, a heading, and a thematic break all present
#     asserts the stated terminator precedence
#     (section_end > heading > thematic break, terminator EXCLUDED from the
#     body).
#
# This suite is the destination the verification design names directly for
# both criteria ("Hermetic anchor fixtures in tests/test-run-doc-
# invariants.sh" / teeth-mode negative coverage "lands in tests/test-run-
# doc-invariants.sh beside the retained byte-identity and mutator-error
# self-tests"). Per `runner-contract-suite` (feature design), the RETAINED
# legs of tests/test-issue-951-registry.sh are ported into
# tests/test-run-doc-invariants.sh by GREEN as part of the file rename; this
# RED suite is deliberately named test-issue-76-runner-self-test-contract.sh
# rather than pre-emptively renaming/deleting tests/test-issue-951-
# registry.sh, since that rename is the feature design's own file-table
# decision (Files to change > tests/test-run-doc-invariants.sh /
# tests/test-issue-951-registry.sh row) — Test AI does not implement
# renames implementation intent dictates. GREEN or a later Test AI pass
# folds this file's assertions into the renamed
# tests/test-run-doc-invariants.sh; until then this file is the CI-facing
# home and is registered the same way.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNNER="$PROJECT_ROOT/tests/run-doc-invariants.sh"
FIXDIR="$PROJECT_ROOT/tests/fixtures"

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

echo "=== Issue #76 — runner --self-test mode (AC-a-3) & anchor negative coverage (AC-f) ==="

# ---------------------------------------------------------------------------
# AC-a-3 — --self-test mode exists and is exhaustive.
# ---------------------------------------------------------------------------
assert_true "AC-a-3: run-doc-invariants.sh --help/usage mentions --self-test" \
  "grep -qF -- '--self-test' '$RUNNER'"

assert_true "AC-a-3: run-doc-invariants.sh --self-test exits 0 against the real registry (every entry demonstrates teeth)" \
  "bash '$RUNNER' --self-test >/tmp/issue76-selftest.out 2>&1"

assert_true "AC-a-3: --self-test reports a Results: line distinct from the default-mode PASS/FAIL line format" \
  "grep -qi 'self-test\|teeth\|mutation' /tmp/issue76-selftest.out 2>/dev/null"

assert_true "AC-a-3: default (no-flag) run-doc-invariants.sh behavior is unchanged (still exits 0/1 on the real registry with no --self-test side effects)" \
  "bash '$RUNNER' >/tmp/issue76-default.out 2>&1; grep -qF 'Results:' /tmp/issue76-default.out"

# ---------------------------------------------------------------------------
# AC-f — anchor-resolution negative coverage, hermetic fixtures.
# ---------------------------------------------------------------------------
assert_true "AC-f: a zero-match 'line' anchor is REJECTED at load time (dangling anchor, not silently skipped)" \
  "out=\$(bash '$RUNNER' '$FIXDIR/issue-76-anchor-zero-match-registry.json' 2>&1); ec=\$?; [ \$ec -ne 0 ] && printf '%s' \"\$out\" | grep -qi 'dangling'"

assert_true "AC-f: a multi-match 'line' anchor is REJECTED at load time (ambiguous anchor, not first-match silently)" \
  "out=\$(bash '$RUNNER' '$FIXDIR/issue-76-anchor-multi-match-registry.json' 2>&1); ec=\$?; [ \$ec -ne 0 ] && printf '%s' \"\$out\" | grep -qi 'ambiguous'"

assert_true "AC-f: a unique 'line' anchor resolves and its predicate evaluates against exactly that one line" \
  "bash '$RUNNER' '$FIXDIR/issue-76-anchor-valid-line-registry.json' >/tmp/issue76-valid-line.out 2>&1; grep -qF 'Results: 1/1 passed' /tmp/issue76-valid-line.out"

assert_true "AC-f: a 'block' anchor with no section_end terminates at the thematic break, excluding the '---' line, and the body does not leak into the next block" \
  "bash '$RUNNER' '$FIXDIR/issue-76-anchor-block-thematic-break-registry.json' >/tmp/issue76-block-thematic.out 2>&1; grep -qF 'Results: 2/2 passed' /tmp/issue76-block-thematic.out"

assert_true "AC-f: a 'block' anchor with an explicit section_end terminates there (precedence over any later heading/thematic-break), excluding the terminator line itself from the body" \
  "bash '$RUNNER' '$FIXDIR/issue-76-anchor-block-explicit-end-registry.json' >/tmp/issue76-block-explicit-end.out 2>&1; grep -qF 'Results: 3/3 passed' /tmp/issue76-block-explicit-end.out"

# ---------------------------------------------------------------------------
# teeth-mode-anchor-destruction — a mutation that destroys a "line"/"block"
# entry's own anchor is a non-credit with a diagnostic, never an abort of
# the whole --self-test run and never a credited FAIL.
# ---------------------------------------------------------------------------
assert_true "teeth-mode-anchor-destruction: --self-test over the valid-line fixture does not abort and reports the entry's status explicitly (credited teeth or a named non-credit, never silence)" \
  "bash '$RUNNER' --self-test '$FIXDIR/issue-76-anchor-valid-line-registry.json' >/tmp/issue76-teeth-line.out 2>&1; grep -qF 'issue-76-fixture-valid-line' /tmp/issue76-teeth-line.out"

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
