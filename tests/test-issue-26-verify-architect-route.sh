#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: VERIFY → ARCHITECT design-contradiction route — Issue #26 (cycle-scoped)
# =============================================================================
# Cycle-scoped DELTA/count guards per the verification design
# (.autoflow/issue-26-verification-design.md §0.2 lane table, §5; ledger E18).
# Docs-only surface (no jest/npm/network) — pure bash + grep + git, following
# the tests/test-issue-843-doc-assertions.sh precedent (assert_true/assert_false).
#
# WHY THIS FILE EXISTS AT ALL. Every literal STATE assertion for this issue is a
# data append to tests/fixtures/doc-invariants.json (29 entries, ids `26-AC*`).
# Only the assertions the registry structurally CANNOT express live here:
# tests/run-doc-invariants.sh:111 rejects any predicate that is not
# present|absent|ordered at load time, so count/delta/diff-shaped guards are
# cycle-lane by construction (docs/doc-invariant-registry.md §1/§2). The four
# below are each of that shape; AC-26-17b additionally could never be a registry
# entry because its target file is itself deleted at merge-cleanup, and a
# registry entry on a missing file is recorded FAIL, not skipped
# (tests/run-doc-invariants.sh:192-195) — it would self-destruct.
#
#   AC-26-9         — over-build fence (PASS pre+post, NOT a RED discriminator):
#                     the CLAUDE.md Regressions line's `max N×` MULTISET is
#                     unchanged by this cycle. E3/R2 rejected a dedicated new
#                     regression cap; §2.4's narrowing folds the design-
#                     contradiction re-deliberation into the existing GATE:PLAN
#                     → ARCHITECT (max 3×) counter and deliberately spells
#                     "capped at 3 per cycle" WITHOUT the `×` token. Baseline
#                     measured at HEAD 3578c4b: max 2×=5, max 3×=2, max 7×=1.
#                     Fails only if GREEN over-builds a new numeric cap.
#   AC-26-16b       — preservation fence (PASS pre+post, NOT a RED
#                     discriminator): this cycle's diff touches NEITHER
#                     .claude/workflows/verify-cause-branch.js NOR
#                     architect-deliberation.js. E3/E4/D1: the new route is an
#                     OUTCOME of the existing Evaluation-AI arbitration, not a
#                     fifth `next_action`, so no script changes. The permanent
#                     half of AC-26-16 is registry entries 26-AC16a-* plus the
#                     pre-existing tests/test-issue-955-…:787 guard.
#   AC-26-17b       — RED discriminator: the stale full-sentence #799 content
#                     carve-out at tests/test-issue-799-inert-cleanup.sh:623 is
#                     REPLACED, not left alongside the new substrings. Left in
#                     place it is a dead filter that silently pre-authorises a
#                     future edit restoring the old unqualified escalation
#                     sentence pair (ledger E21).
#   AC-CI-REGISTER  — RED discriminator: this suite is wired into
#                     .github/workflows/e2e-dummy-target.yml (both `paths:`
#                     trigger blocks + a `run:` step), #798/#799/#800/#843
#                     precedent. AC-CI-d is the COUNT half — the manual-scenario
#                     file's two registrations (pull_request + push); the
#                     pull_request-block registration of THIS suite is pinned in
#                     the registry lane instead (26-AC15a, an `ordered` entry
#                     anchoring the suite path ABOVE the `push:` key).
#
# Not in this file: AC-26-10 (no viable permanent lane — withdrawn, ledger E17)
# and AC-26-11b (SVG render — out of scope, ledger E15). The behavioural claim
# (AC-26-15) and the prose mutual-exclusivity residual of AC-26-6 are routed to
# tests/manual/issue-26-manual-scenarios.md (M2 / M1, ledger E24) — automated
# coverage here is documentary: it proves the routing rule is written,
# positioned, capped and internally consistent, not that an agent obeys it.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
INERT_799="$PROJECT_ROOT/tests/test-issue-799-inert-cleanup.sh"
CI_WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"
BASEREF_LIB="$PROJECT_ROOT/tests/lib/base-ref.sh"

PASS=0; FAIL=0; TESTS=0

# ---------------------------------------------------------------------------
# Helpers (assert_true/assert_false pattern per test-issue-843-doc-assertions.sh)
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
echo "=== AC-26-9 (over-build fence, PASS pre+post) — no new numeric cap on the Regressions line ==="
# The Regressions line is resolved by its durable literal prefix, never by a
# line number, so an upstream insertion cannot dislocate this guard.

REG_LINE_NO="$(grep -n '^\*\*Regressions\*\*' "$CLAUDE_MD" | head -1 | cut -d: -f1)"

if [[ -z "$REG_LINE_NO" ]]; then
  assert_true "AC-26-9-anchor: CLAUDE.md carries a '**Regressions**' line" "false"
  echo "  BLOCK: AC-26-9 multiset unmeasurable (anchor missing)"
  TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
else
  assert_true "AC-26-9-anchor: CLAUDE.md carries a '**Regressions**' line" "true"
  CAP_MULTISET="$(sed -n "${REG_LINE_NO}p" "$CLAUDE_MD" | grep -o 'max [0-9]*×' | sort | uniq -c | awk '{print $2, $3 "=" $1}' | paste -sd' ' -)"
  # Baseline measured at HEAD 3578c4b (verification design §0.4, C-D4):
  # identical at HEAD and against the adopted §2.4 paren form.
  EXPECTED_MULTISET="max 2×=5 max 3×=2 max 7×=1"
  assert_true "AC-26-9: Regressions-line 'max N×' multiset unchanged ('$EXPECTED_MULTISET'), i.e. no new cap introduced (got: '$CAP_MULTISET')" \
    "[ \"\$(printf '%s' '$CAP_MULTISET')\" = \"\$(printf '%s' '$EXPECTED_MULTISET')\" ]"
fi

# =============================================================================
echo ""
echo "=== AC-26-16b (preservation fence, PASS pre+post) — cycle diff touches neither workflow script ==="
# Base-DEPENDENT guard: it MUST fail loud when no base is resolvable, never
# SKIP while still incrementing the test count (tests/lib/base-ref.sh contract).

if [[ ! -f "$BASEREF_LIB" ]]; then
  echo "  BLOCK: tests/lib/base-ref.sh missing — AC-26-16b is base-dependent and cannot be evaluated"
  TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
else
  # shellcheck source=/dev/null
  . "$BASEREF_LIB"
  BASE_REF="$(cd "$PROJECT_ROOT" && resolve_base_ref "${ISSUE_26_BASE_REF:-}" || true)"
  if [[ -z "$BASE_REF" ]]; then
    echo "  BLOCK: no comparison base resolvable (override / GITHUB_BASE_REF / origin/main / main all unavailable) — AC-26-16b counted FAIL, never skipped"
    TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
  else
    CYCLE_FILES="$(cd "$PROJECT_ROOT" && git diff --name-only "$BASE_REF"...HEAD 2>/dev/null || true)"
    assert_false "AC-26-16b-a: cycle diff does not touch .claude/workflows/verify-cause-branch.js" \
      "printf '%s\n' \"\$(cd '$PROJECT_ROOT' && git diff --name-only '$BASE_REF'...HEAD)\" | grep -qx '.claude/workflows/verify-cause-branch.js'"
    assert_false "AC-26-16b-b: cycle diff does not touch .claude/workflows/architect-deliberation.js" \
      "printf '%s\n' \"\$(cd '$PROJECT_ROOT' && git diff --name-only '$BASE_REF'...HEAD)\" | grep -qx '.claude/workflows/architect-deliberation.js'"
  fi
fi

# =============================================================================
echo ""
echo "=== AC-26-17b (RED discriminator) — stale #799 content carve-out REPLACED, not left behind ==="
# tests/test-issue-799-inert-cleanup.sh:623 filters the FULL old sentence pair.
# Once the common substring 'unresolved by Evaluation AI arbitration → human'
# is added (it covers both the removed and the added line, measured), the
# full-sentence entry is fully redundant — a dead filter that silently
# pre-authorises restoring the old sentence pair. It must be gone.

assert_false "AC-26-17b: the stale full-sentence carve-out no longer appears in test-issue-799-inert-cleanup.sh" \
  "grep -qF 'VERIFY deadlock unresolved by Evaluation AI arbitration → human. HANDOFF internal retry exhausted → human.' '$INERT_799'"

# =============================================================================
echo ""
echo "=== AC-CI-REGISTER (RED discriminator) — suite wired into e2e-dummy-target.yml ==="

if [[ -f "$CI_WORKFLOW" ]]; then
  assert_true "AC-CI-a: e2e-dummy-target.yml references test-issue-26-verify-architect-route.sh" \
    "grep -q 'test-issue-26-verify-architect-route' '$CI_WORKFLOW'"
  assert_true "AC-CI-b: reference appears in a 'paths:' trigger block" \
    "ctx=\$(grep -B20 'test-issue-26-verify-architect-route' '$CI_WORKFLOW'); printf '%s\n' \"\$ctx\" | grep -q '^ *paths:'"
  assert_true "AC-CI-c: reference appears in a 'run:' step" \
    "ctx=\$(grep -A2 'test-issue-26-verify-architect-route' '$CI_WORKFLOW'); printf '%s\n' \"\$ctx\" | grep -q 'run: bash tests/test-issue-26-verify-architect-route.sh'"
  # AC-CI-d — COUNT guard, cycle-lane by construction (the registry rejects any
  # predicate outside present|absent|ordered, and `ordered` resolves only the
  # FIRST match of each anchor, so "registered in BOTH paths: blocks" is not
  # expressible as a registry entry). Same shape as the §DR-7 self-registration
  # guard at tests/test-issue-951-registry.sh:740-743. Without it, either
  # tests/manual/issue-26-manual-scenarios.md registration can be dropped
  # silently: AC-CI-a/b/c read only the suite path, and 26-AC15a pins only the
  # pull_request-block occurrence of the suite path.
  assert_true "AC-CI-d: manual-scenario file registered in BOTH paths: blocks (>=2 occurrences)" \
    "[ \"\$(grep -cF \"'tests/manual/issue-26-manual-scenarios.md'\" '$CI_WORKFLOW')\" -ge 2 ]"
else
  assert_true "AC-CI-a: $CI_WORKFLOW exists" "false"
  echo "  BLOCK: AC-CI-b/c/d unmeasurable (workflow file missing) — counted FAIL, never skipped"
  TESTS=$((TESTS + 3)); FAIL=$((FAIL + 3))
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
