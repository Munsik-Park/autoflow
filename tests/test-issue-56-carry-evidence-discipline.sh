#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/workflows/architect-deliberation.js .claude/workflows/verify-cause-branch.js .github/workflows/e2e-dummy-target.yml docs/doc-invariant-registry.md setup/manifest.json test/workflows/run.mjs tests/fixtures/doc-invariants.json tests/lib/base-ref.sh tests/run-doc-invariants.sh
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
#             `const carry = register.size` ternary line (re-anchored by issue #67,
#             which retargets the carry from `openCounters` to the issue register —
#             the surviving intent is unchanged: the carry-assembly line is not a
#             prompt-rule interpolation site);
#             `${COUNTER_EVIDENCE_RULE}` interpolates exactly twice, on the
#             dev-r/test-r prompt lines, never inside the ternary.
#   AC-56-4a — RED discriminator: the citation rule is declared ONCE
#             (`const COUNTER_EVIDENCE_RULE`) and interpolated at both round
#             prompt sites (D2 structural symmetry).
#   AC-56-8  — fence (PASS pre+post): the workflow-regression harness
#             (`node test/workflows/run.mjs`) still exits 0, still prints
#             `all workflow regression tests passed`, and its `ok`-line count
#             equals the literal `EXPECTED_OK` pinned below (verification
#             design §6 pinning rule, ledger L10) — never a derived `31 + N`,
#             which would absorb a silent test loss.
#   AC-56-9  — fence (PASS pre+post): change-surface bound to this cycle's
#             `.claude/` subset (`.claude/workflows/architect-deliberation.js`
#             only); `verify-cause-branch.js` sha256 unchanged (B4).
#
# Branch scoping (GATE:QUALITY FAIL #2, ledger L15): AC-56-8's EXPECTED_OK pin
# and AC-56-9's diff-subset/B4-sha pins are the issue-56 PR's OWN contract, not
# every PR's — this workflow triggers on every PR/push matching its broad
# `paths:` filter (e2e-dummy-target.yml), so an unconditional pin reds an
# unrelated PR or a post-merge main push (reproduced: empty diff subset after
# merge, and a foreign-branch run.mjs still at the pre-#56 ok-count). Scoped to
# the issue-56 dev branch, mirroring commit ea68a4c
# (tests/test-issue-7-oracle-hardening.sh AC-7-7b) exactly: `note_deferred`,
# never a silently-passing skip, when off-branch.
#   AC-56-10 — fence at RED / hard gate mid-GREEN: `setup/manifest.json`'s row
#             for `architect-deliberation.js` hash-matches the live source
#             (gate); both files land within the cycle range (advisory).
#   AC-56-11 — Test-AI-owned surface: this suite is registered in
#             .github/workflows/e2e-dummy-target.yml (both `paths:` blocks +
#             a `run:` step) — expected PASS by end of RED.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKFLOW_JS="$PROJECT_ROOT/.claude/workflows/architect-deliberation.js"
VERIFY_JS="$PROJECT_ROOT/.claude/workflows/verify-cause-branch.js"
MANIFEST="$PROJECT_ROOT/setup/manifest.json"
CI_WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"
BASEREF_LIB="$PROJECT_ROOT/tests/lib/base-ref.sh"

# B4 (verification design §0): verify-cause-branch.js sha256 must stay unchanged (D5 — out of
# this cycle's scope).
B4_SHA="315e2069ae8526078b6149359e3aba92c7da1785547cde7d0fa9a65912494d3b"

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

# Deferred-observable marker (mirrors tests/test-issue-7-oracle-hardening.sh:115,
# commit ea68a4c): does NOT increment TESTS/PASS/FAIL — a branch-scoped lane that
# is inert off its own branch is neither proven nor faked, so it must not count as
# a passing (or failing) test.
note_deferred() {
  echo "  DEFERRED-OBSERVABLE: $1"
}

# Cycle-scoped subset/pin lanes (AC-56-8, AC-56-9) are this cycle's own PR
# contract — scope them to the issue-56 dev branch (GITHUB_HEAD_REF in PR CI,
# the checked-out branch locally), exactly as commit ea68a4c scopes AC-7-7b.
HEAD_BRANCH="${GITHUB_HEAD_REF:-$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)}"

# =============================================================================
echo "=== AC-56-2a (RED discriminator) — constant placement: carry ternary vs. round-prompt sites ==="

CARRY_COUNT="$(grep -c '\${CARRY_NON_EVIDENTIARY}' "$WORKFLOW_JS" || true)"
assert_true "AC-56-2a-carry-count: \${CARRY_NON_EVIDENTIARY} interpolates exactly once (got: $CARRY_COUNT)" \
  "[ \"$CARRY_COUNT\" -eq 1 ]"

CARRY_LINE="$(grep -n '\${CARRY_NON_EVIDENTIARY}' "$WORKFLOW_JS" | head -1)"
assert_true "AC-56-2a-carry-site: the interpolation site is the 'const carry = register.size' ternary line (re-anchored, issue #67 AC19)" \
  "printf '%s' '$CARRY_LINE' | grep -q 'const carry = register.size'"

RULE_COUNT="$(grep -c '\${COUNTER_EVIDENCE_RULE}' "$WORKFLOW_JS" || true)"
assert_true "AC-56-2a-rule-count: \${COUNTER_EVIDENCE_RULE} interpolates exactly twice (got: $RULE_COUNT)" \
  "[ \"$RULE_COUNT\" -eq 2 ]"

RULE_NOT_IN_TERNARY="$(grep -n '\${COUNTER_EVIDENCE_RULE}' "$WORKFLOW_JS" | grep -c 'const carry = register.size' || true)"
assert_true "AC-56-2a-rule-site: no \${COUNTER_EVIDENCE_RULE} occurrence sits on the carry ternary line (re-anchored, issue #67 AC19) (got: $RULE_NOT_IN_TERNARY)" \
  "[ \"$RULE_NOT_IN_TERNARY\" -eq 0 ]"

# =============================================================================
echo ""
echo "=== AC-56-4a (RED discriminator) — citation rule declared once, interpolated at both round sites ==="

DECL_COUNT="$(grep -c 'const COUNTER_EVIDENCE_RULE' "$WORKFLOW_JS" || true)"
assert_true "AC-56-4a-decl: 'const COUNTER_EVIDENCE_RULE' declared exactly once (got: $DECL_COUNT)" \
  "[ \"$DECL_COUNT\" -eq 1 ]"
assert_true "AC-56-4a-interp: \${COUNTER_EVIDENCE_RULE} interpolated exactly twice (got: $RULE_COUNT)" \
  "[ \"$RULE_COUNT\" -eq 2 ]"

# =============================================================================
echo ""
echo "=== AC-56-8 (regression fence, PASS pre+post) — workflow-regression harness ==="

case "$HEAD_BRANCH" in
  dev/*-issue-56|dev/*-issue-56-*)
    # EXPECTED_OK pinning rule (verification design §6, ledger L10): a literal integer,
    # never a derived expression — an open `31 + N` would absorb an accidental test loss,
    # which is the failure this fence exists to catch. Measured at RED close: B1 (31) +
    # six new run.mjs tests (AC-56-1b/2b/3b/4b/5/14b) = 37.
    EXPECTED_OK=37

    HARNESS_OUT="$(cd "$PROJECT_ROOT" && node test/workflows/run.mjs 2>&1)"
    HARNESS_EXIT=$?
    OK_COUNT="$(printf '%s\n' "$HARNESS_OUT" | grep -cE '^[[:space:]]*ok\b' || true)"
    assert_true "AC-56-8a: node test/workflows/run.mjs exits 0" "[ $HARNESS_EXIT -eq 0 ]"
    assert_true "AC-56-8b: harness reports 'all workflow regression tests passed'" \
      "printf '%s\n' \"\$HARNESS_OUT\" | grep -qF 'all workflow regression tests passed'"
    assert_true "AC-56-8c: harness ok-line count == EXPECTED_OK ($EXPECTED_OK) (got: $OK_COUNT)" \
      "[ \"$OK_COUNT\" -eq $EXPECTED_OK ]"
    ;;
  *)
    note_deferred "AC-56-8: EXPECTED_OK=37 regression pin inert off the issue-56 dev branch (head: ${HEAD_BRANCH:-unknown}) — the ok-count baseline (B1 31 + 6 new run.mjs tests) is this cycle's own contract, not every branch's."
    ;;
esac

# =============================================================================
echo ""
echo "=== AC-56-9 (fence, PASS pre+post) — change-surface bound to architect-deliberation.js alone ==="

case "$HEAD_BRANCH" in
  dev/*-issue-56|dev/*-issue-56-*)
    if [[ ! -f "$BASEREF_LIB" ]]; then
      echo "  BLOCK: tests/lib/base-ref.sh missing — AC-56-9a is base-dependent and cannot be evaluated"
      TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
    else
      # shellcheck source=/dev/null
      . "$BASEREF_LIB"
      BASE_REF="$(cd "$PROJECT_ROOT" && resolve_base_ref "${ISSUE_56_BASE_REF:-}" || true)"
      if [[ -z "$BASE_REF" ]]; then
        echo "  BLOCK: no comparison base resolvable — AC-56-9a counted FAIL, never skipped"
        TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
      else
        CLAUDE_DIFF_SUBSET="$(cd "$PROJECT_ROOT" && git diff --name-only "$BASE_REF"...HEAD | grep '^\.claude/' || true)"
        EXPECTED_SUBSET=".claude/workflows/architect-deliberation.js"
        assert_true "AC-56-9a: cycle diff's .claude/ subset == '$EXPECTED_SUBSET' (got: '$(printf '%s' "$CLAUDE_DIFF_SUBSET" | paste -sd, -)')" \
          "[ \"\$(printf '%s' '$CLAUDE_DIFF_SUBSET')\" = \"$EXPECTED_SUBSET\" ]"
      fi
    fi

    CUR_VERIFY_SHA="$(shasum -a 256 "$VERIFY_JS" | awk '{print $1}')"
    assert_true "AC-56-9b: verify-cause-branch.js sha256 unchanged (B4 $B4_SHA) (got: $CUR_VERIFY_SHA)" \
      "[ \"$CUR_VERIFY_SHA\" = \"$B4_SHA\" ]"
    ;;
  *)
    note_deferred "AC-56-9a/9b: cycle-scoped change-surface fence inert off the issue-56 dev branch (head: ${HEAD_BRANCH:-unknown}) — the .claude/ diff-subset bound and the B4 sha pin are this cycle's own PR contract, not every PR's (reproduced: empty diff subset after merge; a foreign PR touching .claude/hooks/check-autoflow-gate.sh)."
    ;;
esac

# =============================================================================
echo ""
echo "=== AC-56-10 — derived artifact: manifest row hash-matches the live source (gate) + cycle-range co-occurrence (advisory) ==="

MANIFEST_SHA="$(jq -r '.artifacts[] | select(.source==".claude/workflows/architect-deliberation.js") | .sha256' "$MANIFEST")"
CUR_ARCH_SHA="$(shasum -a 256 "$WORKFLOW_JS" | awk '{print $1}')"
assert_true "AC-56-10a (gate): setup/manifest.json row sha256 == current architect-deliberation.js sha256 (manifest: $MANIFEST_SHA, current: $CUR_ARCH_SHA)" \
  "[ \"$MANIFEST_SHA\" = \"$CUR_ARCH_SHA\" ]"

if [[ -n "${BASE_REF:-}" ]]; then
  RANGE_FILES="$(cd "$PROJECT_ROOT" && git diff --name-only "$BASE_REF"...HEAD)"
  BOTH_IN_RANGE=true
  printf '%s\n' "$RANGE_FILES" | grep -qx '\.claude/workflows/architect-deliberation\.js' || BOTH_IN_RANGE=false
  printf '%s\n' "$RANGE_FILES" | grep -qx 'setup/manifest\.json' || BOTH_IN_RANGE=false
  echo "  ADVISORY: AC-56-10b co-occurrence over the cycle range: both paths present == $BOTH_IN_RANGE (non-blocking, hash equality above is the gate)"
else
  echo "  ADVISORY: AC-56-10b co-occurrence unmeasurable (no base ref) — non-blocking, hash equality above is the gate"
fi

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
