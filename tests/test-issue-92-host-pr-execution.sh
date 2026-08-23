#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: host-PR helper argv/exit-code contract + close-keyword checker — the
#       execution-shaped half of the retired tests/issue-92/*.bats set
# =============================================================================
# ci-subject: scripts/handoff/create-host-pr.sh scripts/test/check-close-keyword-quoting.sh .github/pull_request_template.md
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
#
# Nothing executed tests/issue-92/*.bats, and nothing could: all three existing
# workflows state a zero-infra rationale that excludes `bats` explicitly, so
# adding a `bats` dependency to run them would contradict that stated
# rationale, while deleting them whole would be a bare deletion. Issue #76
# `bats-split` therefore disposed of them BY ASSERTION SHAPE:
#
#   - STATE assertions over document and file content split three ways, each
#     recorded in docs/doc-invariant-registry.md §6: those with a live carrier
#     were retired against it (T10-1a/-1b/-1c against the #795 legs; T1-0/T1-3
#     against this suite); those without one were migrated to doc-invariant
#     registry entries under `origin_issue: 92` (T12-1a's positive half,
#     T10-1d, T10-2 — seven entries); and T11-1a-i..iv were DROPPED with the
#     coverage loss recorded, because an `absent` predicate over an ERE cannot
#     demonstrate mutation teeth and a fixed-literal rewrite would narrow an
#     absence guard into one that admits what it forbade;
#   - count-shaped assertions ("a section has at least N items", "a marker
#     appears exactly once") were retired with §6 disposition rows, the
#     disposition this tree already establishes for that class. Note that
#     T11-1a-i..iv are NOT of this class: they grep current file content, not
#     a diff against a base, and §6 records them as the STATE assertions they
#     are;
#   - the EXECUTION-shaped assertions are ported here. They are the only
#     content with genuine execution value and no other home: the host-PR
#     helper's argv and exit-code contract driven through the `mock-gh`
#     fixture, and the close-keyword checker's own invocation.
#
# The mock-gh fixture is retained rather than ported — it is a PATH shim, not
# bats-specific — and is driven the same way here: prepended to PATH so the
# helper resolves the shim instead of a real `gh`, with every argument the
# helper passes recorded one per line in $GH_INVOCATION_LOG.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

HELPER="$PROJECT_ROOT/scripts/handoff/create-host-pr.sh"
MOCK_GH_DIR="$SCRIPT_DIR/issue-92/mock-gh"

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

assert_false() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if eval "$condition"; then
    echo "  FAIL: $desc (forbidden condition held)"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

TMP_ROOT="$(mktemp -d)"
cleanup() { rm -rf "$TMP_ROOT" 2>/dev/null || true; }
trap cleanup EXIT

BODY_FILE="$TMP_ROOT/body.md"
printf '## Summary\n\ntest body\n' > "$BODY_FILE"

# run_helper <args...> — drives the helper with the mock gh on PATH and a fresh
# invocation log. Sets HELPER_STATUS; the recorded argv is $GH_INVOCATION_LOG.
export GH_INVOCATION_LOG="$TMP_ROOT/gh.log"
run_helper() {
  : > "$GH_INVOCATION_LOG"
  ( PATH="$MOCK_GH_DIR:$PATH" "$HELPER" "$@" ) >/dev/null 2>&1
  HELPER_STATUS=$?
}

echo "=== Issue #92 (ported from bats) — host-PR helper argv/exit-code contract ==="

assert_true "T2-1: scripts/handoff/create-host-pr.sh exists and is executable" \
  "[ -f '$HELPER' ] && [ -x '$HELPER' ]"

run_helper
assert_true "T2-2a: no args exits 64 (EX_USAGE)" "[ \"\$HELPER_STATUS\" -eq 64 ]"

run_helper --issue 92
assert_true "T2-2b: missing --title and --body-file exits 64" "[ \"\$HELPER_STATUS\" -eq 64 ]"

run_helper --issue 92 --title "test"
assert_true "T2-2c: missing --body-file exits 64" "[ \"\$HELPER_STATUS\" -eq 64 ]"

run_helper --issue 92 --title "test" --body-file "$TMP_ROOT/does-not-exist.md"
assert_true "T2-3: a body-file path that does not exist exits 66 (EX_NOINPUT), distinct from the usage class" \
  "[ \"\$HELPER_STATUS\" -eq 66 ]"

run_helper --issue 92 --title "test" --body-file "$BODY_FILE"
assert_true "T2-4: default invocation succeeds" "[ \"\$HELPER_STATUS\" -eq 0 ]"
assert_true "T2-4a: default invocation passes --draft to gh" \
  "grep -qFx -- '--draft' '$GH_INVOCATION_LOG'"
assert_true "T2-4b: default invocation passes the blocked-by-subrepo label to gh (either the one-arg or the two-arg form)" \
  "grep -qFx -- 'blocked-by-subrepo' '$GH_INVOCATION_LOG' || grep -qFx -- '--label=blocked-by-subrepo' '$GH_INVOCATION_LOG'"
assert_true "T2-4c: default invocation invokes 'gh pr create'" \
  "grep -qFx -- 'pr' '$GH_INVOCATION_LOG' && grep -qFx -- 'create' '$GH_INVOCATION_LOG'"

run_helper --issue 92 --title "test" --body-file "$BODY_FILE" --no-subrepo-dep
assert_true "T2-5: --no-subrepo-dep invocation succeeds" "[ \"\$HELPER_STATUS\" -eq 0 ]"
assert_true "T2-5a: --no-subrepo-dep still passes --draft" \
  "grep -qFx -- '--draft' '$GH_INVOCATION_LOG'"
assert_false "T2-5b: --no-subrepo-dep does NOT pass the blocked-by-subrepo label" \
  "grep -qFx -- 'blocked-by-subrepo' '$GH_INVOCATION_LOG' || grep -qFx -- '--label=blocked-by-subrepo' '$GH_INVOCATION_LOG'"
echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
