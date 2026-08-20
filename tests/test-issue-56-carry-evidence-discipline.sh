#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/workflows/architect-deliberation.js .github/workflows/e2e-dummy-target.yml docs/doc-invariant-registry.md setup/manifest.json test/workflows/run.mjs tests/fixtures/doc-invariants.json tests/run-doc-invariants.sh
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: Carry-channel evidence discipline — Issue #56 (cycle-scoped)
# =============================================================================
# Cycle-scoped DELTA/count/execution guards per the verification design
# (.autoflow/issue-56-verification-design.md §0.1 lane table, §6 RED plan).
# Every permanent STATE assertion for this issue is a data append to
# tests/fixtures/doc-invariants.json (seven entries, ids `56-AC*`). Only the
# assertions the registry structurally CANNOT express live here:
# tests/run-doc-invariants.sh:111 rejects any predicate that is not
# present|absent|ordered at load time, so count/position/diff-shaped guards
# are cycle-lane by construction (docs/doc-invariant-registry.md §1/§2).
#
#   AC-56-2a — RED discriminator: placement of the two hoisted constants.
#             `${CARRY_NON_EVIDENTIARY}` interpolates exactly once, on the
#             `const renderCarry = () => register.size` ternary line (re-anchored by
#             issue #67, which retargets the carry from `openCounters` to the issue
#             register, and again by issue #123, which extracts the inline
#             `const carry = register.size` ternary into the `renderCarry()`
#             function shared by the round prompts and the cap-round closing
#             half-round — the surviving intent is unchanged: the carry-assembly
#             line is not a prompt-rule interpolation site);
#             `${COUNTER_EVIDENCE_RULE}` interpolates exactly three times (issue
#             #123 adds the closing half-round as a third site, alongside the
#             dev-r/test-r prompt lines), never inside the ternary.
#   AC-56-4a — RED discriminator: the citation rule is declared ONCE
#             (`const COUNTER_EVIDENCE_RULE`) and interpolated at both round
#             prompt sites (D2 structural symmetry).
#
# Retired (#107): AC-56-8 (the workflow-regression ok-count pin) and AC-56-9
# (the cycle change-surface / B4-sha fence). Both were gated on a
# dev/*-issue-56 branch, so both went inert the moment issue #56's PR merged.
# AC-56-8's pinned literal was also stale against the single-sourced
# tests/lib/harness-pins.sh, and the same measurement runs unconditionally in
# tests/test-issue-27-composition-oracle.sh. See
# docs/doc-invariant-registry.md §12 and §12.1.
#
#   AC-56-10 — fence at RED / hard gate mid-GREEN: `setup/manifest.json`'s row
#             for `architect-deliberation.js` hash-matches the live source
#             (AC-56-10a, gate). AC-56-10b's cycle-range co-occurrence
#             advisory branch read `$BASE_REF`, whose only writer was
#             AC-56-9's own arm; #107 retired both together (registry §12.1).
#   AC-56-11 — Test-AI-owned surface: this suite is registered in
#             .github/workflows/e2e-dummy-target.yml (both `paths:` blocks +
#             a `run:` step) — expected PASS by end of RED.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKFLOW_JS="$PROJECT_ROOT/.claude/workflows/architect-deliberation.js"
MANIFEST="$PROJECT_ROOT/setup/manifest.json"
CI_WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"

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

# =============================================================================
echo "=== AC-56-2a (RED discriminator) — constant placement: carry ternary vs. round-prompt sites ==="

CARRY_COUNT="$(grep -c '\${CARRY_NON_EVIDENTIARY}' "$WORKFLOW_JS" || true)"
assert_true "AC-56-2a-carry-count: \${CARRY_NON_EVIDENTIARY} interpolates exactly once (got: $CARRY_COUNT)" \
  "[ \"$CARRY_COUNT\" -eq 1 ]"

CARRY_LINE="$(grep -n '\${CARRY_NON_EVIDENTIARY}' "$WORKFLOW_JS" | head -1)"
assert_true "AC-56-2a-carry-site: the interpolation site is the 'const renderCarry = () => register.size' ternary line (re-anchored, issue #67 AC19 then issue #123 extraction)" \
  "printf '%s' '$CARRY_LINE' | grep -q 'const renderCarry = () => register.size'"

RULE_COUNT="$(grep -c '\${COUNTER_EVIDENCE_RULE}' "$WORKFLOW_JS" || true)"
assert_true "AC-56-2a-rule-count: \${COUNTER_EVIDENCE_RULE} interpolates exactly three times (re-anchored, issue #123 adds the closing half-round site) (got: $RULE_COUNT)" \
  "[ \"$RULE_COUNT\" -eq 3 ]"

RULE_NOT_IN_TERNARY="$(grep -n '\${COUNTER_EVIDENCE_RULE}' "$WORKFLOW_JS" | grep -c 'const renderCarry = () => register.size' || true)"
assert_true "AC-56-2a-rule-site: no \${COUNTER_EVIDENCE_RULE} occurrence sits on the carry ternary line (re-anchored, issue #67 AC19 then issue #123 extraction) (got: $RULE_NOT_IN_TERNARY)" \
  "[ \"$RULE_NOT_IN_TERNARY\" -eq 0 ]"

# =============================================================================
echo ""
echo "=== AC-56-4a (RED discriminator) — citation rule declared once, interpolated at every round/closing site ==="

DECL_COUNT="$(grep -c 'const COUNTER_EVIDENCE_RULE' "$WORKFLOW_JS" || true)"
assert_true "AC-56-4a-decl: 'const COUNTER_EVIDENCE_RULE' declared exactly once (got: $DECL_COUNT)" \
  "[ \"$DECL_COUNT\" -eq 1 ]"
assert_true "AC-56-4a-interp: \${COUNTER_EVIDENCE_RULE} interpolated exactly three times (re-anchored, issue #123 adds the closing half-round site) (got: $RULE_COUNT)" \
  "[ \"$RULE_COUNT\" -eq 3 ]"

# =============================================================================
echo ""
echo "=== AC-56-10 — derived artifact: manifest row hash-matches the live source (gate) ==="

MANIFEST_SHA="$(jq -r '.artifacts[] | select(.source==".claude/workflows/architect-deliberation.js") | .sha256' "$MANIFEST")"
CUR_ARCH_SHA="$(shasum -a 256 "$WORKFLOW_JS" | awk '{print $1}')"
assert_true "AC-56-10a (gate): setup/manifest.json row sha256 == current architect-deliberation.js sha256 (manifest: $MANIFEST_SHA, current: $CUR_ARCH_SHA)" \
  "[ \"$MANIFEST_SHA\" = \"$CUR_ARCH_SHA\" ]"

# =============================================================================
echo ""
echo "=== AC-56-11 (Test-AI-owned surface) — cycle suite registered in BOTH paths: trigger blocks + a run: step ==="

if [[ -f "$CI_WORKFLOW" ]]; then
  # Context-scoped idiom (tests/test-issue-27-composition-oracle.sh:373-374): a file-wide
  # occurrence count (>=2) passes vacuously even when BOTH `paths:` entries are missing,
  # as long as the comment line + the `run:` step reference the filename elsewhere (this
  # repo's own e2e-dummy-target.yml carries a comment + run: line beyond the two paths:
  # entries, so a naive >=2 total does not discriminate a dropped paths: entry). Split the
  # file at the `push:` trigger boundary, then scan each half UNBOUNDED WITHIN ITS OWN
  # SECTION (no fixed -B window — a bounded window has finite headroom above the entry and
  # silently loses reach as more entries are added above it by future issues) for whether a
  # `paths:` header precedes the reference anywhere in that half. PUSH_SECTION is bounded at
  # the NEXT top-level key (`permissions:`) — left unbounded to EOF it would swallow the
  # entire `jobs:` section, where this suite's own registration comment (e2e-dummy-target.yml
  # around the #56 step) and its `run:` line ALSO mention the filename, and the block's own
  # `paths:` header (from any surviving sibling entry) would already have set the flag by
  # then — a dropped push `paths:` entry would still read "yes" off those later mentions
  # (GATE:QUALITY FAIL #3, ledger L16, mutation-proven). PR_SECTION needs no such bound: it
  # already ends at `push:`, before the `jobs:` section exists in the scan at all, so it
  # cannot pick up a later comment/run: mention.
  PR_SECTION="$(awk '/^  push:/{exit} {print}' "$CI_WORKFLOW")"
  PUSH_SECTION="$(awk 'f && /^[a-zA-Z]/{exit} f{print} /^  push:/{f=1}' "$CI_WORKFLOW")"

  PR_PATHS_PRECEDES="$(printf '%s\n' "$PR_SECTION" | awk '/^ *paths:/{p=1} /test-issue-56-carry-evidence-discipline\.sh/{print (p==1)?"yes":"no"; f=1; exit} END{if(!f) print "no"}')"
  assert_true "AC-56-11a-pr: reference appears in the pull_request 'paths:' trigger block" \
    "[ \"$PR_PATHS_PRECEDES\" = yes ]"

  PUSH_PATHS_PRECEDES="$(printf '%s\n' "$PUSH_SECTION" | awk '/^ *paths:/{p=1} /test-issue-56-carry-evidence-discipline\.sh/{print (p==1)?"yes":"no"; f=1; exit} END{if(!f) print "no"}')"
  assert_true "AC-56-11a-push: reference appears in the push 'paths:' trigger block" \
    "[ \"$PUSH_PATHS_PRECEDES\" = yes ]"

  assert_true "AC-56-11b: reference appears in a 'run:' step" \
    "ctx=\$(grep -A2 'test-issue-56-carry-evidence-discipline.sh' '$CI_WORKFLOW'); printf '%s\n' \"\$ctx\" | grep -q 'run: bash tests/test-issue-56-carry-evidence-discipline.sh'"
else
  assert_true "AC-56-11a-pr: $CI_WORKFLOW exists" "false"
  echo "  BLOCK: AC-56-11a-push/AC-56-11b unmeasurable (workflow file missing) — counted FAIL, never skipped"
  TESTS=$((TESTS + 2)); FAIL=$((FAIL + 2))
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
