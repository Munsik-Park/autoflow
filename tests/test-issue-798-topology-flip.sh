#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/hooks/check-autoflow-gate.sh CLAUDE.md README.md docs/adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md docs/doc-invariant-registry.md docs/submodule-common-rules.md plugin/autoflow/hooks/check-autoflow-gate.sh scripts/test/check-cycle-scope-guard.sh setup/manifest.json tests/fixtures/doc-invariants.json tests/manual/issue-798-manual-scenarios.md tests/plugin/verify-e2e-dummy-target.sh
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: submodule-detach topology-flip RED/GREEN harness — Issue #798
# ([#785-S11a] 토폴로지 플립)
# =============================================================================
# Tier-1 scripted assertion suite per verification design
# (.autoflow/issue-798-verification-design.md). Docs+config change (no jest,
# no npm) — mirrors tests/test-issue-795-handoff-removal.sh /
# tests/test-issue-797-doc-invocation.sh: assert_true/assert_false over
# git-plumbing + grep.
#
# [MUST] Git-plumbing, not filesystem. Every detach assertion queries
# HEAD/the index (`git ls-tree`, `git ls-files -s`, `git config --file
# .gitmodules`), never a working-tree filesystem probe — `git rm --cached
# services` leaves `services/` on disk as an untracked local checkout, and a
# CI fresh clone has no `services/` at all. Filesystem probes would give
# environment-sensitive, non-reproducible RED/GREEN (verification design §0
# / R1).
#
# Scope (verification design §1/§2):
#   AC1  GITMODULES-CLEAR   — .gitmodules absent from HEAD (D-1 = delete)
#   AC2  GITLINK-CLEAR      — no 160000 gitlink at `services` in HEAD/index
#   AC3  COUNT-ZERO         — non-vacuity keystone: submodule count == 0
#   AC12 CI-ENFORCED        — the suite + `.gitmodules` are CI-registered
#
# Migrated out of this file, assertion carried elsewhere (issue #109, registry
# §13.2 — the assert-less section headers were removed; the carriers below are
# `tests/fixtures/doc-invariants.json` ids):
#   DOC-CLAUDE-CLASS (CLAUDE.md self-classification flip)
#        → 798-AC5-positive-singlerepo, 798-AC5-negative-multirepo-gone
#   README-SYNC (dangling submodule references removed, degenerate prose kept)
#        → 798-AC15a-no-recurse, 798-AC15b-no-submodule-tree,
#          798-AC15c-degenerate-prose
#
# Not in this file (verification design §2/§5):
#   AC4  local .git/config + .git/modules residue        → tests/manual/issue-798-manual-scenarios.md
#   AC8  HANDOFF reclassification (behavioral)            → tests/manual/issue-798-manual-scenarios.md
#   AC11 host-purity DELTA regression (reuse, unchanged)  → tests/test-issue-788-host-purity-delta.sh
#   AC13 resync-submodules.sh clean run-through           → DEFERRED: verification design §2 item 4
#        states this is added "only after the D-2 guard lands" — the oracle
#        needs the script's empty-gm_names fix in place (D-2) before it can
#        assert exit-0 run-through instead of pipefail-abort. Adding it now
#        against the live (still-populated) .gitmodules would be vacuously
#        GREEN (today's script never reaches the empty-gm_names branch),
#        which is not a valid RED. Add at VERIFY once GREEN lands D-2.
#   AC14 purity-ratchet burn-down (reuse) — feature §5 confirms the
#        conditional is structurally unreachable for #798 (no baseline entry
#        references `services`); stays GREEN unconditionally via
#        tests/plugin/verify-e2e-dummy-target.sh E2a arm, no new assertion.
#
# RED expectation (pre-change): AC1/AC2/AC3/AC12 FAIL.
# AC3 COUNT-ZERO is the non-vacuity keystone — a
# pre-change PASS on any detach assertion means the test is mis-scoped.
# The branch-relative preservation guards this file used to carry (the Secondary-marker
# diff fence, the ADR-0015 no-hunk fence and the two no-new-timing scope fences) were
# retired in issue #121: each was an un-gated DELTA over a merged cycle's own diff, so on
# any later branch it silently re-aimed at that branch. Their dispositions and the carriers
# that took over are docs/doc-invariant-registry.md §16.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
README_MD="$PROJECT_ROOT/README.md"

PASS=0; FAIL=0; TESTS=0

# ---------------------------------------------------------------------------
# Helpers (assert_* pattern per tests/test-issue-788-host-purity-delta.sh)
# ---------------------------------------------------------------------------

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

assert_false() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if (cd "$PROJECT_ROOT" && eval "$condition"); then
    echo "  FAIL: $desc (forbidden condition held)"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

# =============================================================================
echo "=== AC1 GITMODULES-CLEAR — .gitmodules absent from HEAD (D-1=delete) ==="
# Presence-first branch (D-1 settled = delete): absence of the blob at HEAD is
# the PASS condition. Never runs `git show HEAD:.gitmodules` unconditionally —
# under D-1 that errors "path does not exist in HEAD" and would abort a set -e
# suite (DQ-7). Defensive fallback only fires if a .gitmodules blob still
# exists at HEAD (pre-change today, or a future regression).
gitmodules_tree_entry="$(git ls-tree HEAD -- .gitmodules 2>/dev/null || true)"
if [[ -z "$gitmodules_tree_entry" ]]; then
  assert_true "AC1: .gitmodules absent from HEAD (git ls-tree empty)" "true"
else
  echo "  (defensive fallback: .gitmodules blob present at HEAD — checking for [submodule stanza)"
  assert_false "AC1 (fallback): no [submodule stanza in committed .gitmodules" \
    "git show HEAD:.gitmodules | grep -qE '^\\[submodule'"
fi

# =============================================================================
echo ""
echo "=== AC2 GITLINK-CLEAR — no gitlink at 'services' in committed tree ==="

assert_true "AC2a: git ls-tree HEAD -- services is empty" \
  "[ -z \"\$(git ls-tree HEAD -- services 2>/dev/null)\" ]"
assert_true "AC2b: git ls-files -s -- services has no 160000 mode row" \
  "! git ls-files -s -- services 2>/dev/null | grep -q '^160000'"

# =============================================================================
echo ""
echo "=== AC3 COUNT-ZERO — non-vacuity keystone: submodule count == 0 ==="

assert_true "AC3a: git submodule status is empty" \
  "[ -z \"\$(git submodule status 2>/dev/null)\" ]"
assert_true "AC3b: HEAD .gitmodules path-entry count == 0" \
  "[ \"\$(git show HEAD:.gitmodules 2>/dev/null | grep -cE '^\\[submodule' || true)\" -eq 0 ]"

# =============================================================================
echo ""
echo "=== AC12 CI-ENFORCED — the #798 suite is CI-registered ==="

ci_home=""
for wf in ".github/workflows/e2e-dummy-target.yml" ".github/workflows/topology-flip.yml"; do
  if [[ -f "$PROJECT_ROOT/$wf" ]] && grep -q 'test-issue-798-topology-flip' "$PROJECT_ROOT/$wf" 2>/dev/null; then
    ci_home="$wf"
    break
  fi
done

if [[ -n "$ci_home" ]]; then
  echo "  CI home: $ci_home"
  assert_true "AC12a: $ci_home references tests/test-issue-798-topology-flip.sh" "true"
  assert_true "AC12b: $ci_home paths: trigger lists .gitmodules" \
    "ctx=\$(grep -A5 '^ *paths:' '$PROJECT_ROOT/$ci_home'); printf '%s\n' \"\$ctx\" | grep -qF '.gitmodules'"
else
  assert_true "AC12a: some workflow references tests/test-issue-798-topology-flip.sh" "false"
  echo "  SKIP: AC12b (no CI home found yet)"
  TESTS=$((TESTS + 1))
fi

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
