#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: Adoption-side evidence discipline — Issue #59 (cycle-scoped)
# =============================================================================
# Cycle-scoped DELTA/count/hash/execution guards per the verification design
# (.autoflow/issue-59-verification-design.md §0.1 lane table, §1, §5.4).
# The five permanent STATE assertions for this issue (characteristic substrings
# A8-A12 of the new ADOPTION_EVIDENCE_RULE constant) are a data append to
# tests/fixtures/doc-invariants.json (ids `59-AC*`). Only the assertions the
# registry structurally CANNOT express (count/position/order/hash/execution)
# live here (docs/doc-invariant-registry.md §1/§2), mirroring the #56/#27
# sibling suites this file is composed against.
#
#   AC-59-7    — RED discriminator: `const ADOPTION_EVIDENCE_RULE` declared
#                exactly once.
#   AC-59-8a   — RED discriminator: `${ADOPTION_EVIDENCE_RULE}` interpolated
#                exactly four times.
#   AC-59-8b   — the four sites are exactly dev-draft/test-draft/dev-r/test-r,
#                never the `const carry = openCounters.length` ternary line.
#   AC-59-8c   — #56's own constant counts are byte-immutable (D4).
#   AC-59-8d   — round-prompt insertion ORDER:
#                `${COUNTER_EVIDENCE_RULE}${ADOPTION_EVIDENCE_RULE}${carry}`.
#   AC-59-9    — fence (PASS pre+post): setup/manifest.json row sha256 ==
#                live architect-deliberation.js sha256 (derived artifact).
#   AC-59-10   — fence (PASS only post-GREEN, branch-scoped): the
#                workflow-regression harness (node test/workflows/run.mjs)
#                exits 0, prints the banner, and its `ok`-line count equals the
#                design-fixed literal EXPECTED_OK (43 = B1's 37 + six new
#                run.mjs tests, never a derived `37 + N` — the #56 pinning
#                convention).
#   AC-59-11a/b — fence (branch-scoped): cycle `.claude/` diff subset ==
#                architect-deliberation.js only; verify-cause-branch.js sha256
#                unchanged (B4) — necessary because AC-56-9b is inert here.
#   AC-59-11c  — fence (unconditional): no `56-AC*`/`27-AC*` registry entry on
#                this file was edited or dropped (file-scoped count == 12).
#   AC-59-11d  — fence (branch-scoped, multi-minute — do not run under a short
#                timeout): every unconditional cross-cycle change-surface guard
#                this cycle's own diff can trip still passes at its
#                `main`-measured pre-change count — a static allow-list read is
#                explicitly rejected as the oracle (verification design §4 E7).
#   AC-59-12a/12b — Test-AI-owned surface: this suite registered in BOTH
#                e2e-dummy-target.yml `paths:` trigger blocks + a `run:` step.
#   AC-59-12c  — the yml edit moves no other cycle's fixed CI window: real
#                re-runs of the canonical cross-cycle suite list settled by
#                the decision ledger (E22): 799 + 798 + 27 + 35 + 56.
#   AC-59-14   — RED discriminator + fence: the shared harness ok-count pin
#                (tests/test-issue-27-composition-oracle.sh:328) is bumped to
#                43 in the same commit as C4, a real re-run of that suite
#                still passes, and the two pins (that literal and this
#                suite's own EXPECTED_OK) agree (cross-pin equality, D18).
#   AC-59-15(a) — RED discriminator (branch-scoped): the re-run oracles above
#                are measured against a NON-EMPTY diff containing this
#                cycle's own change surface — a re-run against an empty diff
#                (B11) proves nothing.
#   AC-59-16   — fence (unconditional): the two adjacent negative-control pins
#                (manifest artifact count 47; the derived pre-existing
#                registry total) are untouched by this cycle's additions.
#   AC-59-17   — fence (unconditional): the tracked-source SPDX header set is
#                intact, including through its aggregator (test-issue-985 +
#                test-issue-1-guard-contract.sh) — this cycle's own new
#                tracked `.sh` file must carry the two SPDX header lines (D17).
#   AC-59-18   — fence (unconditional): the manifest same-commit obligation
#                holds against all three of its fences (AC-56-10a, 955's
#                AC4-DOGFOOD, 952's AC5/AC5(T2)).
#
# AC-59-15(b) (full-tree sweep determination) is NOT a lane in this suite — it
# is a standalone VERIFY-phase driver authored alongside this file:
# tests/issue-59-full-sweep-driver.sh (D24). Running it here would be directly
# self-recursive (the driver's own `tests/test-issue-*.sh` glob would pick up
# this file) and would blow this suite's own runtime budget.
#
# Branch scoping mirrors tests/test-issue-56-carry-evidence-discipline.sh
# exactly: `note_deferred`, never a silently-passing skip, when off-branch —
# this cycle's own diff-dependent fences are this PR's contract, not every
# PR's.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKFLOW_JS="$PROJECT_ROOT/.claude/workflows/architect-deliberation.js"
VERIFY_JS="$PROJECT_ROOT/.claude/workflows/verify-cause-branch.js"
MANIFEST="$PROJECT_ROOT/setup/manifest.json"
CI_WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"
BASEREF_LIB="$PROJECT_ROOT/tests/lib/base-ref.sh"
REGISTRY="$PROJECT_ROOT/tests/fixtures/doc-invariants.json"
REGISTRY_RUNNER="$PROJECT_ROOT/tests/run-doc-invariants.sh"

# B4 (verification design §0): verify-cause-branch.js sha256 must stay unchanged (D5 — out
# of this cycle's scope).
B4_SHA="315e2069ae8526078b6149359e3aba92c7da1785547cde7d0fa9a65912494d3b"

# EXPECTED_OK (D18/§5.3): one pin with two homes — this literal and
# tests/test-issue-27-composition-oracle.sh:328. A design-fixed literal integer, never a
# derived `37 + N` (AC-59-14(c) enforces the cross-pin equality below).
EXPECTED_OK=43

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

# Deferred-observable marker (mirrors tests/test-issue-56-carry-evidence-discipline.sh): does
# NOT increment TESTS/PASS/FAIL — a branch-scoped lane that is inert off its own branch is
# neither proven nor faked, so it must not count as a passing (or failing) test.
note_deferred() {
  echo "  DEFERRED-OBSERVABLE: $1"
}

# Extracts "passed/total/failed" from a suite's own "Results: X/Y passed, Z failed" line.
suite_counts() {
  local out="$1"
  local passed total failed
  passed="$(printf '%s\n' "$out" | grep -oE 'Results: [0-9]+/[0-9]+ passed, [0-9]+ failed' | tail -1 | sed -E 's/Results: ([0-9]+)\/([0-9]+) passed, ([0-9]+) failed/\1/')"
  total="$(printf '%s\n' "$out" | grep -oE 'Results: [0-9]+/[0-9]+ passed, [0-9]+ failed' | tail -1 | sed -E 's/Results: ([0-9]+)\/([0-9]+) passed, ([0-9]+) failed/\2/')"
  failed="$(printf '%s\n' "$out" | grep -oE 'Results: [0-9]+/[0-9]+ passed, [0-9]+ failed' | tail -1 | sed -E 's/Results: ([0-9]+)\/([0-9]+) passed, ([0-9]+) failed/\3/')"
  printf '%s %s %s' "${passed:--1}" "${total:--1}" "${failed:--1}"
}

# Cycle-scoped diff-dependent lanes (AC-59-10, 11a, 11b, 11d, 15(a)) are this cycle's OWN PR
# contract — scoped to the issue-59 dev branch, mirroring commit ea68a4c
# (tests/test-issue-7-oracle-hardening.sh AC-7-7b) and tests/test-issue-56-…:90 exactly.
HEAD_BRANCH="${GITHUB_HEAD_REF:-$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)}"

BASE_REF=""
if [[ -f "$BASEREF_LIB" ]]; then
  # shellcheck source=/dev/null
  . "$BASEREF_LIB"
  BASE_REF="$(cd "$PROJECT_ROOT" && resolve_base_ref "${ISSUE_59_BASE_REF:-}" || true)"
fi

# =============================================================================
echo "=== AC-59-7 (RED discriminator) — ADOPTION_EVIDENCE_RULE declared exactly once ==="

DECL_COUNT="$(grep -c 'const ADOPTION_EVIDENCE_RULE' "$WORKFLOW_JS" || true)"
assert_true "AC-59-7: 'const ADOPTION_EVIDENCE_RULE' declared exactly once (got: $DECL_COUNT)" \
  "[ \"$DECL_COUNT\" -eq 1 ]"

# =============================================================================
echo ""
echo "=== AC-59-8a (RED discriminator) — interpolated exactly four times ==="

INTERP_COUNT="$(grep -c '\${ADOPTION_EVIDENCE_RULE}' "$WORKFLOW_JS" || true)"
assert_true "AC-59-8a: \${ADOPTION_EVIDENCE_RULE} interpolates exactly 4 times (got: $INTERP_COUNT)" \
  "[ \"$INTERP_COUNT\" -eq 4 ]"

# =============================================================================
echo ""
echo "=== AC-59-8b — the four sites are dev-draft/test-draft/dev-r/test-r, never the carry ternary ==="

DEV_DRAFT_SITE="$(grep '\${ADOPTION_EVIDENCE_RULE}' "$WORKFLOW_JS" | grep -c 'You are the Developer AI in AutoFlow ARCHITECT' || true)"
TEST_DRAFT_SITE="$(grep '\${ADOPTION_EVIDENCE_RULE}' "$WORKFLOW_JS" | grep -c 'You are the Test AI in AutoFlow ARCHITECT' || true)"
DEV_ROUND_SITE="$(grep '\${ADOPTION_EVIDENCE_RULE}' "$WORKFLOW_JS" | grep -c 'You are the Developer AI\. Round' || true)"
TEST_ROUND_SITE="$(grep '\${ADOPTION_EVIDENCE_RULE}' "$WORKFLOW_JS" | grep -c 'You are the Test AI\. Round' || true)"
CARRY_TERNARY_SITE="$(grep '\${ADOPTION_EVIDENCE_RULE}' "$WORKFLOW_JS" | grep -c 'const carry = openCounters.length' || true)"

assert_true "AC-59-8b-dev-draft: exactly one interpolation line matches the dev-draft prompt prefix (got: $DEV_DRAFT_SITE)" \
  "[ \"$DEV_DRAFT_SITE\" -eq 1 ]"
assert_true "AC-59-8b-test-draft: exactly one interpolation line matches the test-draft prompt prefix (got: $TEST_DRAFT_SITE)" \
  "[ \"$TEST_DRAFT_SITE\" -eq 1 ]"
assert_true "AC-59-8b-dev-round: exactly one interpolation line matches the dev-round prompt prefix (got: $DEV_ROUND_SITE)" \
  "[ \"$DEV_ROUND_SITE\" -eq 1 ]"
assert_true "AC-59-8b-test-round: exactly one interpolation line matches the test-round prompt prefix (got: $TEST_ROUND_SITE)" \
  "[ \"$TEST_ROUND_SITE\" -eq 1 ]"
assert_true "AC-59-8b-unconditional: zero interpolation occurrences sit on the carry ternary line (got: $CARRY_TERNARY_SITE)" \
  "[ \"$CARRY_TERNARY_SITE\" -eq 0 ]"

# =============================================================================
echo ""
echo "=== AC-59-8c — #56's own constant counts stay byte-immutable (D4) ==="

CARRY56_COUNT="$(grep -c '\${CARRY_NON_EVIDENTIARY}' "$WORKFLOW_JS" || true)"
RULE56_INTERP_COUNT="$(grep -c '\${COUNTER_EVIDENCE_RULE}' "$WORKFLOW_JS" || true)"
RULE56_DECL_COUNT="$(grep -c 'const COUNTER_EVIDENCE_RULE' "$WORKFLOW_JS" || true)"

assert_true "AC-59-8c-carry: \${CARRY_NON_EVIDENTIARY} still interpolates exactly once (got: $CARRY56_COUNT)" \
  "[ \"$CARRY56_COUNT\" -eq 1 ]"
assert_true "AC-59-8c-rule-interp: \${COUNTER_EVIDENCE_RULE} still interpolates exactly twice (got: $RULE56_INTERP_COUNT)" \
  "[ \"$RULE56_INTERP_COUNT\" -eq 2 ]"
assert_true "AC-59-8c-rule-decl: 'const COUNTER_EVIDENCE_RULE' still declared exactly once (got: $RULE56_DECL_COUNT)" \
  "[ \"$RULE56_DECL_COUNT\" -eq 1 ]"

# =============================================================================
echo ""
echo "=== AC-59-8d (RED discriminator) — round-prompt insertion ORDER ==="

ORDER_COUNT="$(grep -c '\${COUNTER_EVIDENCE_RULE}\${ADOPTION_EVIDENCE_RULE}\${carry}' "$WORKFLOW_JS" || true)"
assert_true "AC-59-8d: the contiguous sequence \${COUNTER_EVIDENCE_RULE}\${ADOPTION_EVIDENCE_RULE}\${carry} occurs exactly 2 times (got: $ORDER_COUNT)" \
  "[ \"$ORDER_COUNT\" -eq 2 ]"

# =============================================================================
echo ""
echo "=== AC-59-9 (fence, PASS pre+post) — derived artifact: manifest row hash-matches the live source ==="

MANIFEST_SHA="$(jq -r '.artifacts[] | select(.source==".claude/workflows/architect-deliberation.js") | .sha256' "$MANIFEST")"
CUR_ARCH_SHA="$(shasum -a 256 "$WORKFLOW_JS" | awk '{print $1}')"
assert_true "AC-59-9: setup/manifest.json row sha256 == current architect-deliberation.js sha256 (manifest: $MANIFEST_SHA, current: $CUR_ARCH_SHA)" \
  "[ \"$MANIFEST_SHA\" = \"$CUR_ARCH_SHA\" ]"

# =============================================================================
echo ""
echo "=== AC-59-10 (RED discriminator, branch-scoped) — workflow-regression harness ==="

case "$HEAD_BRANCH" in
  dev/*-issue-59|dev/*-issue-59-*)
    HARNESS_OUT="$(cd "$PROJECT_ROOT" && node test/workflows/run.mjs 2>&1)"
    HARNESS_EXIT=$?
    OK_COUNT="$(printf '%s\n' "$HARNESS_OUT" | grep -cE '^[[:space:]]*ok\b' || true)"
    assert_true "AC-59-10a: node test/workflows/run.mjs exits 0" "[ $HARNESS_EXIT -eq 0 ]"
    assert_true "AC-59-10b: harness reports 'all workflow regression tests passed'" \
      "printf '%s\n' \"\$HARNESS_OUT\" | grep -qF 'all workflow regression tests passed'"
    assert_true "AC-59-10c: harness ok-line count == EXPECTED_OK ($EXPECTED_OK) (got: $OK_COUNT)" \
      "[ \"$OK_COUNT\" -eq $EXPECTED_OK ]"
    ;;
  *)
    note_deferred "AC-59-10: EXPECTED_OK=$EXPECTED_OK regression pin inert off the issue-59 dev branch (head: ${HEAD_BRANCH:-unknown}) — this cycle's own ok-count baseline is this PR's contract, not every branch's."
    ;;
esac

# =============================================================================
echo ""
echo "=== AC-59-11a/11b (RED discriminator + fence, branch-scoped) — change-surface bound to architect-deliberation.js alone ==="

case "$HEAD_BRANCH" in
  dev/*-issue-59|dev/*-issue-59-*)
    if [[ -z "$BASE_REF" ]]; then
      echo "  BLOCK: no comparison base resolvable — AC-59-11a counted FAIL, never skipped"
      TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
    else
      CLAUDE_DIFF_SUBSET="$(cd "$PROJECT_ROOT" && git diff --name-only "$BASE_REF"...HEAD | grep '^\.claude/' || true)"
      EXPECTED_SUBSET=".claude/workflows/architect-deliberation.js"
      assert_true "AC-59-11a: cycle diff's .claude/ subset == '$EXPECTED_SUBSET' (got: '$(printf '%s' "$CLAUDE_DIFF_SUBSET" | paste -sd, -)')" \
        "[ \"\$(printf '%s' '$CLAUDE_DIFF_SUBSET')\" = \"$EXPECTED_SUBSET\" ]"
    fi

    CUR_VERIFY_SHA="$(shasum -a 256 "$VERIFY_JS" | awk '{print $1}')"
    assert_true "AC-59-11b: verify-cause-branch.js sha256 unchanged (B4 $B4_SHA) (got: $CUR_VERIFY_SHA)" \
      "[ \"$CUR_VERIFY_SHA\" = \"$B4_SHA\" ]"
    ;;
  *)
    note_deferred "AC-59-11a/11b: cycle-scoped change-surface fence inert off the issue-59 dev branch (head: ${HEAD_BRANCH:-unknown})."
    ;;
esac

# =============================================================================
echo ""
echo "=== AC-59-11c (fence, unconditional) — no 56-AC*/27-AC* registry entry on this file was edited or dropped ==="

REGISTRY_EXIT_OUT="$(bash "$REGISTRY_RUNNER" 2>&1)"
REGISTRY_EXIT=$?
LEGACY_COUNT="$(jq '[.invariants[] | select(.file==".claude/workflows/architect-deliberation.js" and (.origin_issue==56 or .origin_issue==27))] | length' "$REGISTRY")"
assert_true "AC-59-11c-runner: tests/run-doc-invariants.sh exits 0" "[ $REGISTRY_EXIT -eq 0 ]"
assert_true "AC-59-11c-count: 56-AC*/27-AC* entries scoped to architect-deliberation.js == 12 (got: $LEGACY_COUNT)" \
  "[ \"$LEGACY_COUNT\" -eq 12 ]"

# =============================================================================
echo ""
echo "=== AC-59-11d (fence, branch-scoped, multi-minute — budget >= 600s, never run under a short timeout) ==="
echo "=== every unconditional cross-cycle change-surface guard re-run against the real diff, at its main-measured count ==="

case "$HEAD_BRANCH" in
  dev/*-issue-59|dev/*-issue-59-*)
    OUT_798="$(cd "$PROJECT_ROOT" && bash tests/test-issue-798-topology-flip.sh 2>&1)"
    OUT_799="$(cd "$PROJECT_ROOT" && bash tests/test-issue-799-inert-cleanup.sh 2>&1)"
    OUT_846="$(cd "$PROJECT_ROOT" && bash tests/test-issue-846-doc-assertions.sh 2>&1)"
    OUT_848="$(cd "$PROJECT_ROOT" && bash tests/test-issue-848-doc-assertions.sh 2>&1)"
    OUT_952="$(cd "$PROJECT_ROOT" && bash tests/test-issue-952-wizard-removal.sh 2>&1)"
    OUT_955="$(cd "$PROJECT_ROOT" && bash tests/test-issue-955-subagent-background-ban.sh 2>&1)"
    OUT_T1="$(cd "$PROJECT_ROOT" && bash tests/test-issue-1-guard-contract.sh 2>&1)"

    read -r P798 T798 F798 <<<"$(suite_counts "$OUT_798")"
    read -r P799 T799 F799 <<<"$(suite_counts "$OUT_799")"
    read -r P846 T846 F846 <<<"$(suite_counts "$OUT_846")"
    read -r P848 T848 F848 <<<"$(suite_counts "$OUT_848")"
    read -r P952 T952 F952 <<<"$(suite_counts "$OUT_952")"
    read -r P955 T955 F955 <<<"$(suite_counts "$OUT_955")"
    read -r PT1 TT1 FT1 <<<"$(suite_counts "$OUT_T1")"

    assert_true "AC-59-11d-798: test-issue-798-topology-flip.sh == 20/20, 0 failed (got: $P798/$T798, $F798 failed)" \
      "[ \"$T798\" -eq 20 ] && [ \"$F798\" -eq 0 ]"
    assert_true "AC-59-11d-799: test-issue-799-inert-cleanup.sh == 31/31, 0 failed (got: $P799/$T799, $F799 failed)" \
      "[ \"$T799\" -eq 31 ] && [ \"$F799\" -eq 0 ]"
    assert_true "AC-59-11d-846: test-issue-846-doc-assertions.sh == 23/23, 0 failed (got: $P846/$T846, $F846 failed)" \
      "[ \"$T846\" -eq 23 ] && [ \"$F846\" -eq 0 ]"
    assert_true "AC-59-11d-848: test-issue-848-doc-assertions.sh == 32/32, 0 failed (got: $P848/$T848, $F848 failed)" \
      "[ \"$T848\" -eq 32 ] && [ \"$F848\" -eq 0 ]"
    assert_true "AC-59-11d-952: test-issue-952-wizard-removal.sh == 53/53, 0 failed (got: $P952/$T952, $F952 failed)" \
      "[ \"$T952\" -eq 53 ] && [ \"$F952\" -eq 0 ]"
    assert_true "AC-59-11d-955: test-issue-955-subagent-background-ban.sh == 57/57, 0 failed (got: $P955/$T955, $F955 failed)" \
      "[ \"$T955\" -eq 57 ] && [ \"$F955\" -eq 0 ]"
    assert_true "AC-59-11d-test1: test-issue-1-guard-contract.sh (N1 aggregator) == 32/32, 0 failed (got: $PT1/$TT1, $FT1 failed)" \
      "[ \"$TT1\" -eq 32 ] && [ \"$FT1\" -eq 0 ]"

    # AC-59-18 reuses the 952/955 real re-runs above rather than invoking them a second
    # time (the manifest same-commit obligation's diff-membership fences live inside those
    # same suites — verification design §4 E9).
    assert_true "AC-59-18-955: 955 AC4-DOGFOOD (manifest-in-diff fence) does not regress the suite's own pass count" \
      "[ \"$F955\" -eq 0 ]"
    assert_true "AC-59-18-952: 952 AC5/AC5(T2) (manifest-in-diff + tests/plugin/ delegation) does not regress the suite's own pass count" \
      "[ \"$F952\" -eq 0 ]"
    ;;
  *)
    note_deferred "AC-59-11d/AC-59-18: cross-cycle change-surface re-run set inert off the issue-59 dev branch (head: ${HEAD_BRANCH:-unknown}) — a lane that cannot fail off-branch must not count as passing."
    ;;
esac

# =============================================================================
echo ""
echo "=== AC-59-12a/12b (Test-AI-owned surface) — cycle suite registered in BOTH paths: trigger blocks + a run: step ==="

if [[ -f "$CI_WORKFLOW" ]]; then
  # Section-split awk idiom (tests/test-issue-56-carry-evidence-discipline.sh AC-56-11):
  # PR_SECTION ends at `push:`; PUSH_SECTION is bounded at the next top-level key so a
  # naive file-wide occurrence count cannot pass vacuously off the run: step / comment
  # alone.
  PR_SECTION="$(awk '/^  push:/{exit} {print}' "$CI_WORKFLOW")"
  PUSH_SECTION="$(awk 'f && /^[a-zA-Z]/{exit} f{print} /^  push:/{f=1}' "$CI_WORKFLOW")"

  PR_PATHS_PRECEDES="$(printf '%s\n' "$PR_SECTION" | awk '/^ *paths:/{p=1} /test-issue-59-adoption-evidence-discipline\.sh/{print (p==1)?"yes":"no"; f=1; exit} END{if(!f) print "no"}')"
  assert_true "AC-59-12a-pr: reference appears in the pull_request 'paths:' trigger block" \
    "[ \"$PR_PATHS_PRECEDES\" = yes ]"

  PUSH_PATHS_PRECEDES="$(printf '%s\n' "$PUSH_SECTION" | awk '/^ *paths:/{p=1} /test-issue-59-adoption-evidence-discipline\.sh/{print (p==1)?"yes":"no"; f=1; exit} END{if(!f) print "no"}')"
  assert_true "AC-59-12a-push: reference appears in the push 'paths:' trigger block" \
    "[ \"$PUSH_PATHS_PRECEDES\" = yes ]"

  assert_true "AC-59-12b: reference appears in a 'run:' step" \
    "ctx=\$(grep -A2 'test-issue-59-adoption-evidence-discipline.sh' '$CI_WORKFLOW'); printf '%s\n' \"\$ctx\" | grep -q 'run: bash tests/test-issue-59-adoption-evidence-discipline.sh'"

  assert_true "AC-59-12a-manual-pr: manual-scenario file registered in the pull_request 'paths:' block" \
    "ctx=\$(awk '/^  push:/{exit} {print}' '$CI_WORKFLOW'); printf '%s\n' \"\$ctx\" | grep -qF \"'tests/manual/issue-59-manual-scenarios.md'\""
  assert_true "AC-59-12a-manual-push: manual-scenario file registered in the push 'paths:' block" \
    "ctx=\$(awk 'f && /^[a-zA-Z]/{exit} f{print} /^  push:/{f=1}' '$CI_WORKFLOW'); printf '%s\n' \"\$ctx\" | grep -qF \"'tests/manual/issue-59-manual-scenarios.md'\""
else
  assert_true "AC-59-12a-pr: $CI_WORKFLOW exists" "false"
  echo "  BLOCK: AC-59-12a-push/12b/manual unmeasurable (workflow file missing) — counted FAIL, never skipped"
  TESTS=$((TESTS + 4)); FAIL=$((FAIL + 4))
fi

# =============================================================================
echo ""
echo "=== AC-59-12c — the yml edit moves no other cycle's fixed CI window (E22 canonical list: 799+798+27+35+56) ==="

OUT_799_WINDOW="$(cd "$PROJECT_ROOT" && bash tests/test-issue-799-inert-cleanup.sh 2>&1)"
OUT_798_WINDOW="$(cd "$PROJECT_ROOT" && bash tests/test-issue-798-topology-flip.sh 2>&1)"
OUT_27_WINDOW="$(cd "$PROJECT_ROOT" && bash tests/test-issue-27-composition-oracle.sh 2>&1)"
OUT_35_WINDOW="$(cd "$PROJECT_ROOT" && bash tests/test-issue-35-phase-marker.sh 2>&1)"
OUT_56_WINDOW="$(cd "$PROJECT_ROOT" && bash tests/test-issue-56-carry-evidence-discipline.sh 2>&1)"

read -r P799W T799W F799W <<<"$(suite_counts "$OUT_799_WINDOW")"
read -r P798W T798W F798W <<<"$(suite_counts "$OUT_798_WINDOW")"
read -r P27W T27W F27W <<<"$(suite_counts "$OUT_27_WINDOW")"
read -r P35W T35W F35W <<<"$(suite_counts "$OUT_35_WINDOW")"
read -r P56W T56W F56W <<<"$(suite_counts "$OUT_56_WINDOW")"

assert_true "AC-59-12c-799: test-issue-799-inert-cleanup.sh window (AC6-ci -A40) unaffected == 31/31 (got: $P799W/$T799W)" \
  "[ \"$T799W\" -eq 31 ] && [ \"$P799W\" -eq \"$T799W\" ]"
assert_true "AC-59-12c-798: test-issue-798-topology-flip.sh window unaffected == 20/20 (got: $P798W/$T798W)" \
  "[ \"$T798W\" -eq 20 ] && [ \"$P798W\" -eq \"$T798W\" ]"
assert_true "AC-59-12c-27: test-issue-27-composition-oracle.sh window unaffected == 23/23 (got: $P27W/$T27W)" \
  "[ \"$T27W\" -eq 23 ] && [ \"$P27W\" -eq \"$T27W\" ]"
assert_true "AC-59-12c-35: test-issue-35-phase-marker.sh (control) unaffected == 137/137 (got: $P35W/$T35W)" \
  "[ \"$T35W\" -eq 137 ] && [ \"$P35W\" -eq \"$T35W\" ]"
assert_true "AC-59-12c-56: test-issue-56-carry-evidence-discipline.sh (control) unaffected == 10/10 (got: $P56W/$T56W)" \
  "[ \"$T56W\" -eq 10 ] && [ \"$P56W\" -eq \"$T56W\" ]"

# =============================================================================
echo ""
echo "=== AC-59-14 (RED discriminator + fence) — shared harness ok-count pin bumped in the same commit ==="

CANON_SUITE="$PROJECT_ROOT/tests/test-issue-27-composition-oracle.sh"
NEW_COUNT_LINE="$(grep -c "\-eq $EXPECTED_OK \]\"" "$CANON_SUITE" || true)"
STALE_ASSERT_LINE="$(grep -c "assert_true.*-eq 37" "$CANON_SUITE" || true)"
STALE_LABEL="$(grep -cF "AC-27-20c: harness ok-line count == B14 (37)" "$CANON_SUITE" || true)"
NEW_LABEL="$(grep -cF "AC-27-20c: harness ok-line count == B14 ($EXPECTED_OK)" "$CANON_SUITE" || true)"

assert_true "AC-59-14a1: test-issue-27's assertion line pins -eq $EXPECTED_OK exactly once (got: $NEW_COUNT_LINE)" \
  "[ \"$NEW_COUNT_LINE\" -eq 1 ]"
assert_true "AC-59-14a2: no assert_true line still pins the stale -eq 37 (got: $STALE_ASSERT_LINE)" \
  "[ \"$STALE_ASSERT_LINE\" -eq 0 ]"
assert_true "AC-59-14a3-stale-label: the stale '(37)' assertion label is gone (got: $STALE_LABEL)" \
  "[ \"$STALE_LABEL\" -eq 0 ]"
assert_true "AC-59-14a3-new-label: the bumped '($EXPECTED_OK)' assertion label is present exactly once (got: $NEW_LABEL)" \
  "[ \"$NEW_LABEL\" -eq 1 ]"

OUT_27_REAL="$(cd "$PROJECT_ROOT" && bash tests/test-issue-27-composition-oracle.sh 2>&1)"
read -r P27R T27R F27R <<<"$(suite_counts "$OUT_27_REAL")"
assert_true "AC-59-14b: real re-run of test-issue-27-composition-oracle.sh == 23/23, 0 failed (got: $P27R/$T27R, $F27R failed)" \
  "[ \"$T27R\" -eq 23 ] && [ \"$F27R\" -eq 0 ]"

CANON_LITERAL="$(grep -oE '\-eq [0-9]+ \]"$' "$CANON_SUITE" | grep -oE '[0-9]+' | tail -1)"
assert_true "AC-59-14c: cross-pin equality — test-issue-27's ok-count literal ($CANON_LITERAL) == this suite's EXPECTED_OK ($EXPECTED_OK)" \
  "[ \"$CANON_LITERAL\" = \"$EXPECTED_OK\" ]"

# =============================================================================
echo ""
echo "=== AC-59-15(a) (RED discriminator, branch-scoped) — non-vacuity: the diff is non-empty and contains the change surface ==="

case "$HEAD_BRANCH" in
  dev/*-issue-59|dev/*-issue-59-*)
    if [[ -z "$BASE_REF" ]]; then
      echo "  BLOCK: no comparison base resolvable — AC-59-15a counted FAIL, never skipped"
      TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
    else
      DIFF_FILES="$(cd "$PROJECT_ROOT" && git diff --name-only "$BASE_REF"...HEAD)"
      assert_true "AC-59-15a-nonempty: cycle diff vs $BASE_REF is non-empty" \
        "[ -n \"\$(printf '%s' '$DIFF_FILES')\" ]"
      for required in \
        ".claude/workflows/architect-deliberation.js" \
        "test/workflows/run.mjs" \
        "tests/test-issue-27-composition-oracle.sh" \
        "tests/test-issue-798-topology-flip.sh" \
        "tests/test-issue-799-inert-cleanup.sh" \
        "tests/test-issue-846-doc-assertions.sh" \
        "tests/test-issue-848-doc-assertions.sh" \
        "tests/test-issue-952-wizard-removal.sh" \
        "tests/test-issue-955-subagent-background-ban.sh"
      do
        assert_true "AC-59-15a-contains: diff contains $required" \
          "printf '%s\n' \"\$(cd '$PROJECT_ROOT' && git diff --name-only '$BASE_REF'...HEAD)\" | grep -qx '$required'"
      done
    fi
    ;;
  *)
    note_deferred "AC-59-15a: non-vacuity assertion inert off the issue-59 dev branch (head: ${HEAD_BRANCH:-unknown}) — meaningless without this cycle's own base."
    ;;
esac

# =============================================================================
echo ""
echo "=== AC-59-16 (fence, unconditional) — negative-control pins are untouched ==="

ARTIFACT_COUNT="$(jq '.artifacts | length' "$MANIFEST")"
assert_true "AC-59-16a: setup/manifest.json artifact count still == 47 (got: $ARTIFACT_COUNT)" \
  "[ \"$ARTIFACT_COUNT\" -eq 47 ]"

REGISTRY_OUT="$(bash "$REGISTRY_RUNNER" 2>&1)"
PRE_EXISTING_FAILS="$(printf '%s\n' "$REGISTRY_OUT" | grep '^  FAIL: ' | awk '{print $2}' | grep -cv '^27-AC' || true)"
PRE_EXISTING_PASSES="$(printf '%s\n' "$REGISTRY_OUT" | grep '^  PASS: ' | awk '{print $2}' | grep -cv '^27-AC' || true)"
PRE_EXISTING_TOTAL="$(jq '[.invariants[] | select(.id | startswith("27-AC") | not)] | length' "$REGISTRY")"
assert_true "AC-59-16b: derived pre-existing (non-27-AC) registry PASS count == every pre-existing (non-27-AC) entry (got: $PRE_EXISTING_PASSES of $PRE_EXISTING_TOTAL, $PRE_EXISTING_FAILS failed)" \
  "[ \"$PRE_EXISTING_PASSES\" -eq \"$PRE_EXISTING_TOTAL\" ] && [ \"$PRE_EXISTING_FAILS\" -eq 0 ]"

# =============================================================================
echo ""
echo "=== AC-59-17 (fence, unconditional) — tracked-source SPDX header set intact, including through its aggregator ==="

OUT_985="$(cd "$PROJECT_ROOT" && bash tests/test-issue-985-doc-assertions.sh 2>&1)"
read -r P985 T985 F985 <<<"$(suite_counts "$OUT_985")"
assert_true "AC-59-17a: real re-run of test-issue-985-doc-assertions.sh == 30/30, 0 failed (got: $P985/$T985, $F985 failed)" \
  "[ \"$T985\" -eq 30 ] && [ \"$F985\" -eq 0 ]"

OUT_T1_SPDX="$(cd "$PROJECT_ROOT" && bash tests/test-issue-1-guard-contract.sh 2>&1)"
read -r PT1S TT1S FT1S <<<"$(suite_counts "$OUT_T1_SPDX")"
assert_true "AC-59-17b: real re-run of test-issue-1-guard-contract.sh (N1 aggregator) == 32/32, 0 failed (got: $PT1S/$TT1S, $FT1S failed)" \
  "[ \"$TT1S\" -eq 32 ] && [ \"$FT1S\" -eq 0 ]"

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
