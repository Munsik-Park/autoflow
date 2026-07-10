#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Shared base-ref resolver — Issue #951 (AC4)
# =============================================================================
# One sourced function, `resolve_base_ref`, that resolves a comparison base
# commit for a base-dependent (DELTA) doc-invariant guard and FAILS LOUD when
# no base is resolvable — replacing the per-suite inline `merge-base HEAD main`
# lines that silently `SKIP` on a CI checkout lacking a local `main`
# (Phase B cases 4/5).
#
# This is the doc-invariant lane's single definition site (ledger E9): the
# runner and every future cycle-scoped doc-invariant RED suite source this
# file instead of re-inlining `merge-base HEAD main`. It deliberately does
# NOT unify scripts/test/check-host-purity-delta.sh, which keeps its own
# established injectable --base/--head resolver (#788 precedent).
#
# Precedence (feature design §4.1):
#   explicit override arg -> GITHUB_BASE_REF (CI pull_request) -> origin/main
#   -> local main -> return 1 (caller MUST fail loud, never silent SKIP).
#
# Contract: prints a resolvable base SHA on stdout and returns 0, or returns
# non-zero and prints nothing. A base-DEPENDENT caller whose resolve_base_ref
# returns non-zero MUST emit a visible BLOCK/FAIL and count it a failure —
# never a SKIP that still increments the test count.
# =============================================================================

# resolve_base_ref [override] -> base SHA on stdout (0), or non-zero (fail-loud)
resolve_base_ref() {
  local override="${1:-}"
  if [[ -n "$override" ]] && git rev-parse --verify -q "$override^{commit}" >/dev/null 2>&1; then
    echo "$override"
    return 0
  fi
  if [[ -n "${GITHUB_BASE_REF:-}" ]] \
     && git rev-parse --verify -q "origin/${GITHUB_BASE_REF}^{commit}" >/dev/null 2>&1; then
    git merge-base HEAD "origin/${GITHUB_BASE_REF}"
    return 0
  fi
  if git rev-parse --verify -q "origin/main^{commit}" >/dev/null 2>&1; then
    git merge-base HEAD origin/main
    return 0
  fi
  if git rev-parse --verify -q "main^{commit}" >/dev/null 2>&1; then
    git merge-base HEAD main
    return 0
  fi
  return 1
}
