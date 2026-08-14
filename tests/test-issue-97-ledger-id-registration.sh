#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .github/workflows/contract-suites.yml tests/test-ledger-entry-id.sh
# =============================================================================
# Test: CI registration for the new ledger-entry-id standing suite — Issue #97
# (cycle-scoped DELTA suite — this cycle's own CI-wiring diff, NOT a
# permanent property of tests/test-ledger-entry-id.sh)
# =============================================================================
# AC-suite-registered per .autoflow/issue-97-verification-design.md: this
# cycle's diff must add tests/test-ledger-entry-id.sh's `# ci-subject:` paths
# to BOTH contract-suites.yml `paths:` blocks (pull_request and push) and give
# it a `run:` step. Backed by (and made permanently redundant, once landed,
# by) the STANDING lints scripts/test/check-suite-ci-coverage.sh (reachability
# closure) and tests/test-workflow-trigger-conformance.sh (registration
# effectiveness) — those two already run unconditionally on every branch and
# are NOT re-implemented here.
#
# Per docs/doc-invariant-registry.md §1/§2: a DELTA/CI-registration guard is
# cycle-scoped, branch-gated by dev/*-issue-97, and deleted (together with its
# own contract-suites.yml paths:/run: rows) in the cycle's final commit before
# DELIVER — its permanent counterpart already lives in the two standing lints
# named above, so nothing is lost when this file is retired.
#
# RED expectation: neither tests/test-ledger-entry-id.sh nor this file itself
# is registered yet, so every assertion below fails for the right reason
# (missing CI wiring), and the standing lints (run manually here as the
# reachability oracle) currently report both new spec files as orphans.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/tests/lib/base-ref.sh"

CONTRACT_SUITES="$PROJECT_ROOT/.github/workflows/contract-suites.yml"
NEW_SUITE_PATH="tests/test-ledger-entry-id.sh"

PASS=0; FAIL=0; TESTS=0

assert_true() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if (cd "$PROJECT_ROOT" && eval "$condition"); then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

note_deferred() { echo "  DEFERRED-OBSERVABLE: $1"; }

on_issue97_branch() {
  case "${GITHUB_HEAD_REF:-$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)}" in
    dev/*-issue-97|dev/*-issue-97-*) return 0 ;;
    *) return 1 ;;
  esac
}

echo "=== Issue #97 — ledger-entry-id CI registration (cycle-scoped) ==="

if on_issue97_branch; then
  BASE_REF="$(resolve_base_ref)" || true

  assert_true "AC-suite-registered: $NEW_SUITE_PATH appears in the pull_request paths: block" \
    "awk '/^on:/{f=1} f && /pull_request:/{p=1} p && /^  push:/{exit} p' '$CONTRACT_SUITES' | grep -qF \"'$NEW_SUITE_PATH'\""

  assert_true "AC-suite-registered: $NEW_SUITE_PATH appears in the push paths: block" \
    "awk '/^  push:/{f=1} f' '$CONTRACT_SUITES' | grep -qF \"'$NEW_SUITE_PATH'\""

  assert_true "AC-suite-registered: a run: step invokes $NEW_SUITE_PATH" \
    "grep -qF 'run: bash $NEW_SUITE_PATH' '$CONTRACT_SUITES'"

  echo ""
  echo "=== Backing oracle (informational): standing reachability lints over the real tree ==="
  if bash "$PROJECT_ROOT/scripts/test/check-suite-ci-coverage.sh" >/tmp/issue97-ci-coverage.$$ 2>&1; then
    echo "  PASS (backing): check-suite-ci-coverage.sh reports no orphan suites"
    PASS=$((PASS + 1))
  else
    echo "  FAIL (backing): check-suite-ci-coverage.sh reports an orphan (expected pre-GREEN — new suites not yet wired)"
    tail -5 /tmp/issue97-ci-coverage.$$ | sed 's/^/    /'
    FAIL=$((FAIL + 1))
  fi
  TESTS=$((TESTS + 1))
  rm -f /tmp/issue97-ci-coverage.$$
else
  note_deferred "scope: inert off the issue-97 dev branch"
fi

echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
