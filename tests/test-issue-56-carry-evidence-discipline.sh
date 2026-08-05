#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
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
#             `const carry = openCounters.length` ternary line;
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

# =============================================================================
echo "=== AC-56-2a (RED discriminator) — constant placement: carry ternary vs. round-prompt sites ==="

CARRY_COUNT="$(grep -c '\${CARRY_NON_EVIDENTIARY}' "$WORKFLOW_JS" || true)"
assert_true "AC-56-2a-carry-count: \${CARRY_NON_EVIDENTIARY} interpolates exactly once (got: $CARRY_COUNT)" \
  "[ \"$CARRY_COUNT\" -eq 1 ]"

CARRY_LINE="$(grep -n '\${CARRY_NON_EVIDENTIARY}' "$WORKFLOW_JS" | head -1)"
assert_true "AC-56-2a-carry-site: the interpolation site is the 'const carry = openCounters.length' ternary line" \
  "printf '%s' '$CARRY_LINE' | grep -q 'const carry = openCounters.length'"

RULE_COUNT="$(grep -c '\${COUNTER_EVIDENCE_RULE}' "$WORKFLOW_JS" || true)"
assert_true "AC-56-2a-rule-count: \${COUNTER_EVIDENCE_RULE} interpolates exactly twice (got: $RULE_COUNT)" \
  "[ \"$RULE_COUNT\" -eq 2 ]"

RULE_NOT_IN_TERNARY="$(grep -n '\${COUNTER_EVIDENCE_RULE}' "$WORKFLOW_JS" | grep -c 'const carry = openCounters.length' || true)"
assert_true "AC-56-2a-rule-site: no \${COUNTER_EVIDENCE_RULE} occurrence sits on the carry ternary line (got: $RULE_NOT_IN_TERNARY)" \
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

# =============================================================================
echo ""
echo "=== AC-56-9 (fence, PASS pre+post) — change-surface bound to architect-deliberation.js alone ==="

if [[ ! -f "$BASEREF_LIB" ]]; then
  echo "  BLOCK: tests/lib/base-ref.sh missing — AC-56-9 is base-dependent and cannot be evaluated"
  TESTS=$((TESTS + 2)); FAIL=$((FAIL + 2))
else
  # shellcheck source=/dev/null
  . "$BASEREF_LIB"
  BASE_REF="$(cd "$PROJECT_ROOT" && resolve_base_ref "${ISSUE_56_BASE_REF:-}" || true)"
  if [[ -z "$BASE_REF" ]]; then
    echo "  BLOCK: no comparison base resolvable — AC-56-9 counted FAIL, never skipped"
    TESTS=$((TESTS + 2)); FAIL=$((FAIL + 2))
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
  # file at the `push:` trigger boundary and require the nearest line preceding the
  # reference to be a `paths:` header WITHIN EACH half — capture first, then match
  # (SIGPIPE-safe per docs/submodule-common-rules.md > Testing Standards).
  PR_SECTION="$(awk '/^  push:/{exit} {print}' "$CI_WORKFLOW")"
  PUSH_SECTION="$(awk 'f{print} /^  push:/{f=1}' "$CI_WORKFLOW")"

  PR_CTX="$(printf '%s\n' "$PR_SECTION" | grep -B90 'test-issue-56-carry-evidence-discipline.sh' || true)"
  assert_true "AC-56-11a-pr: reference appears in the pull_request 'paths:' trigger block" \
    "printf '%s\n' \"\$PR_CTX\" | grep -q '^ *paths:'"

  PUSH_CTX="$(printf '%s\n' "$PUSH_SECTION" | grep -B90 'test-issue-56-carry-evidence-discipline.sh' || true)"
  assert_true "AC-56-11a-push: reference appears in the push 'paths:' trigger block" \
    "printf '%s\n' \"\$PUSH_CTX\" | grep -q '^ *paths:'"

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
