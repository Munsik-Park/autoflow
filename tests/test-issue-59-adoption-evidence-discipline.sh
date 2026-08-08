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
# --- cycle 2 (review-response, codex Medium: unguarded -1/-1/-1 sentinel) ---
#   AC-59-19a  — unconditional, RED discriminator: `base_measured` is the ONE
#                place the sentinel is interpreted (7-row table).
#   AC-59-19b  — unconditional, RED discriminator, self-scoped structural grep:
#                no delta comparison bypasses the guard (12 `-ge $BT...`
#                conditions, all 12 also carry a `base_measured` conjunct).
#   AC-59-20a  — unconditional, characterization: the worktree-add failure
#                path is reachable via real git and returns the sentinel.
#   AC-59-20b  — unconditional, characterization: the Results:-less parse path
#                returns the sentinel.
#   AC-59-20c  — unconditional, RED discriminator: the real `suite_result_at_ref`
#                composed with the real `base_measured`, no re-typed copy.
#   AC-59-21   — branch-scoped: each of the 12 AC-59-11d/12c lanes gets a
#                separate base-measurement precondition assertion, plus the
#                `base_measured` conjunct leading its own delta condition.
#   AC-59-22a  — unconditional, RED discriminator, self-scoped structural grep:
#                12 precondition labels + 12 delta labels exist, each naming
#                its suite; no precondition label carries a claim-shaped verb.
#   AC-59-22b  — unconditional, RED discriminator: every precondition label
#                interpolates the base failed count ($BF...).
#   AC-59-23   — regression fence (VERIFY evidence, not a lane in this file):
#                full suite + the six guard suites (798/799/846/848/952/955).
#   AC-59-24   — manual (tests/manual/issue-59-manual-scenarios.md): a genuine
#                host-level worktree failure also produces the loud FAIL.
#
# --- Cycle 3 (review-response) — codex Medium on PR #61: the DRIVER's own
# `git worktree add` failure was silently reported as a measured `ALREADY RED`
# (.autoflow/issue-59-verification-design.md cycle-3 section, `:1544-`). Fixed
# in tests/issue-59-full-sweep-driver.sh; the lanes below exercise the REAL
# driver file, `cp`'d byte-for-byte into a throwaway `git init` fixture repo
# and run as a program (route (iv), verification design cycle-3 §1) — never a
# re-typed copy of its logic.
#   AC-59-25   — RED discriminator: an unresolvable base ref is reported as
#                per-suite INCONCLUSIVE, never a fabricated ALREADY RED.
#   AC-59-26   — RED discriminator: a suite absent at a resolvable base is
#                labelled NEW AT HEAD, never ALREADY RED (the second
#                fabricated route the same mechanism opens).
#   AC-59-27   — characterization, four shapes: green-HEAD/unmeasurable-base
#                stays clean (a); a genuinely measured red base still
#                classifies ALREADY RED (b); a named (c) / unnamed (d)
#                regression against a resolvable, measured base still
#                classifies correctly.
#   AC-59-28   — RED discriminator, self-scoped structural grep over the
#                driver: the base-exit seed is never a literal exit-status
#                value, every base-exit comparison is measured-guarded, the
#                ALREADY RED verdict form has exactly one home, and the
#                per-suite INCONCLUSIVE label is distinct from both
#                script-level INCONCLUSIVE exits.
#   AC-59-29   — RED discriminator: the driver's real exit code is 0 only for
#                a clean sweep with a resolvable, measured base; 2 while any
#                suite is inconclusive; 1 while an unnamed regression exists
#                (outranking INCONCLUSIVE — asserted structurally, conjunct
#                P); and the 600s budget default is unchanged (conjunct D).
#                GATE:PLAN carry-note (ledger E48): the clean-fixture row is
#                pinned to a resolvable base SHA, not an unresolvable ref, so
#                it genuinely exercises a successful worktree add + base run.
#   AC-59-31   — characterization: standalone execution against the LIVE tree
#                still prints its banner + self-exclusion notice, bash -n
#                stays clean, no worktree residue.
#   AC-59-32   — RED discriminator (sound only once the driver's `mktemp -d`
#                honours a `TMPDIR`-scoped, identifiable template): no
#                `autoflow-sweep-wt.*` directory survives the failed-add path.
#   AC-59-35   — characterization: the one lane that drives the LIVE
#                repository's own worktree channel (a single failed add),
#                left unchanged.
#   AC-59-35b  — fixture-hygiene fences bound to every harness-F lane: copy
#                fidelity held before each run (i), and the live repo carries
#                exactly one worktree entry + empty status afterward (ii).
#   AC-59-33   — regression fence (VERIFY evidence, not a lane in this file):
#                the four cycle-2 structural pins unchanged; a full suite
#                re-run green with its total risen by exactly the cycle-3
#                count; the six cycle guard suites (798/799/846/848/952/955)
#                green; zero CI references to the driver; bash -n clean.
#                GATE:PLAN carry-note (ledger E48): tests/test-issue-964-
#                sigpipe-safe-pipes.sh's AC2-A zero-remaining hazard-shape
#                guard is ALSO included in this regression fence — every
#                cycle-3 lane below is written without the
#                `identifier | grep -q`/`| grep -m` shape that guard forbids
#                (bash-native `[[ ]]`/here-string matching instead), so this
#                cycle's own additions cannot re-open the count AC2-A closed.
#   AC-59-34   — manual (tests/manual/issue-59-manual-scenarios.md, scenario
#                M5): a genuine host-level worktree failure against the
#                driver also produces the loud FAIL, never ALREADY RED/PASS.
#   AC-59-30   — WITHDRAWN (source-safety was a property of the withdrawn
#                seam approach; route (iv) needs no source-safety change).
#                Id retired, never reused.
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
EXPECTED_OK=58

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

# Runs tests/<suite_name> against a git ref OTHER than the live working tree, in an
# isolated worktree on the SAME host/environment this script itself is running in, and
# returns the same "passed total failed" triplet suite_counts() extracts.
#
# Ledger E33 (PR #61, CI run 31088600592): AC-59-11d/12c originally pinned literal
# totals measured on the author's local host. Five lanes FAILed on the GitHub Actions
# runner because environment-conditional sub-tests in the target suites (798/799/955)
# don't register there, shifting the real total below the local literal — and three
# more (846/848/952) happened to match by luck. A host-pinned literal cannot be fixed
# by re-measuring once; the fix is to stop comparing against a fixed number at all and
# instead compare HEAD against a real re-run of the SAME suite at the comparison base,
# executed in THIS SAME run (same host, same environment, same conditional-registration
# behavior) — the delta is environment-invariant even though the absolute totals are not.
suite_result_at_ref() {
  local ref="$1" suite_name="$2"
  local wt out
  wt="$(mktemp -d)"
  if ! git -C "$PROJECT_ROOT" worktree add -q --detach "$wt" "$ref" >/dev/null 2>&1; then
    rm -rf "$wt"
    printf '%s %s %s' "-1" "-1" "-1"
    return
  fi
  if [[ -f "$wt/tests/$suite_name" ]]; then
    out="$(cd "$wt" && bash "tests/$suite_name" 2>&1)"
  else
    out=""
  fi
  git -C "$PROJECT_ROOT" worktree remove --force "$wt" >/dev/null 2>&1
  suite_counts "$out"
}

# The ONE place the `-1 -1 -1` unmeasurable sentinel emitted by suite_counts /
# suite_result_at_ref above is interpreted (cycle 2, feature design D1/D2). Every consumer of
# a base triple must lead its comparison with this predicate: without it the delta comparison
# is true for every non-negative HEAD total once the base total reads -1, so an unmeasured
# base prints a green delta line (codex Medium on PR #61). AC-59-19b greps for exactly that
# leading conjunct, so this comment states the condition in prose rather than in its source
# form — a literal copy here would be counted as a 13th, unguarded delta condition.
#
# The shape check `^[0-9]+$` is deliberately wider than `!= -1` — it also rejects an empty
# field (what `read` yields when the helper printed nothing) and any non-numeric value, both
# of which would otherwise reach `[ ... -ge ... ]` and surface as `integer expression
# expected` under a misleading label. Measurability only: a measured-but-red base
# (15 18 3) is ACCEPTED (D4).
base_measured() {
  local field
  for field in "$@"; do
    [[ "$field" =~ ^[0-9]+$ ]] || return 1
  done
  return 0
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
    if [[ -z "$BASE_REF" ]]; then
      # 7 AC-59-21 preconditions + 7 AC-59-11d deltas + 2 AC-59-18 — the fallback must cost
      # exactly what the lane would otherwise contribute, or the suite total would depend on
      # whether the base resolved.
      echo "  BLOCK: no comparison base resolvable — AC-59-21/AC-59-11d/AC-59-18 counted FAIL, never skipped"
      TESTS=$((TESTS + 16)); FAIL=$((FAIL + 16))
    else
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

      # Same-environment baseline (ledger E33): re-run each suite a SECOND time, at the
      # comparison base, in THIS SAME job/host — never a literal captured on a different
      # machine. An environment-conditional lane (e.g. a sub-test that doesn't register
      # on this specific runner) shifts BOTH the base and head totals identically, so the
      # delta below stays valid across hosts where a fixed literal is not (that is exactly
      # what broke on the GitHub Actions runner).
      read -r BP798 BT798 BF798 <<<"$(suite_result_at_ref "$BASE_REF" "test-issue-798-topology-flip.sh")"
      read -r BP799 BT799 BF799 <<<"$(suite_result_at_ref "$BASE_REF" "test-issue-799-inert-cleanup.sh")"
      read -r BP846 BT846 BF846 <<<"$(suite_result_at_ref "$BASE_REF" "test-issue-846-doc-assertions.sh")"
      read -r BP848 BT848 BF848 <<<"$(suite_result_at_ref "$BASE_REF" "test-issue-848-doc-assertions.sh")"
      read -r BP952 BT952 BF952 <<<"$(suite_result_at_ref "$BASE_REF" "test-issue-952-wizard-removal.sh")"
      read -r BP955 BT955 BF955 <<<"$(suite_result_at_ref "$BASE_REF" "test-issue-955-subagent-background-ban.sh")"
      read -r BPT1 BTT1 BFT1 <<<"$(suite_result_at_ref "$BASE_REF" "test-issue-1-guard-contract.sh")"

      # Each lane is two counted assertions (D3): a neutral-noun-phrase precondition naming
      # the base measurement, then the delta verdict whose condition LEADS with the same
      # guard — so an unmeasured base fails both lines instead of printing a green delta.
      assert_true "AC-59-21-798: base measurement of test-issue-798-topology-flip.sh at $BASE_REF (got base $BP798/$BT798, $BF798 failed)" \
        "base_measured \"$BP798\" \"$BT798\" \"$BF798\""
      assert_true "AC-59-11d-798: test-issue-798-topology-flip.sh — 0 failed at HEAD, total not below base (got: $P798/$T798 vs base $BP798/$BT798)" \
        "base_measured \"$BP798\" \"$BT798\" \"$BF798\" && [ \"$F798\" -eq 0 ] && [ \"$T798\" -ge \"$BT798\" ]"
      assert_true "AC-59-21-799: base measurement of test-issue-799-inert-cleanup.sh at $BASE_REF (got base $BP799/$BT799, $BF799 failed)" \
        "base_measured \"$BP799\" \"$BT799\" \"$BF799\""
      assert_true "AC-59-11d-799: test-issue-799-inert-cleanup.sh — 0 failed at HEAD, total not below base (got: $P799/$T799 vs base $BP799/$BT799)" \
        "base_measured \"$BP799\" \"$BT799\" \"$BF799\" && [ \"$F799\" -eq 0 ] && [ \"$T799\" -ge \"$BT799\" ]"
      assert_true "AC-59-21-846: base measurement of test-issue-846-doc-assertions.sh at $BASE_REF (got base $BP846/$BT846, $BF846 failed)" \
        "base_measured \"$BP846\" \"$BT846\" \"$BF846\""
      assert_true "AC-59-11d-846: test-issue-846-doc-assertions.sh — 0 failed at HEAD, total not below base (got: $P846/$T846 vs base $BP846/$BT846)" \
        "base_measured \"$BP846\" \"$BT846\" \"$BF846\" && [ \"$F846\" -eq 0 ] && [ \"$T846\" -ge \"$BT846\" ]"
      assert_true "AC-59-21-848: base measurement of test-issue-848-doc-assertions.sh at $BASE_REF (got base $BP848/$BT848, $BF848 failed)" \
        "base_measured \"$BP848\" \"$BT848\" \"$BF848\""
      assert_true "AC-59-11d-848: test-issue-848-doc-assertions.sh — 0 failed at HEAD, total not below base (got: $P848/$T848 vs base $BP848/$BT848)" \
        "base_measured \"$BP848\" \"$BT848\" \"$BF848\" && [ \"$F848\" -eq 0 ] && [ \"$T848\" -ge \"$BT848\" ]"
      assert_true "AC-59-21-952: base measurement of test-issue-952-wizard-removal.sh at $BASE_REF (got base $BP952/$BT952, $BF952 failed)" \
        "base_measured \"$BP952\" \"$BT952\" \"$BF952\""
      assert_true "AC-59-11d-952: test-issue-952-wizard-removal.sh — 0 failed at HEAD, total not below base (got: $P952/$T952 vs base $BP952/$BT952)" \
        "base_measured \"$BP952\" \"$BT952\" \"$BF952\" && [ \"$F952\" -eq 0 ] && [ \"$T952\" -ge \"$BT952\" ]"
      assert_true "AC-59-21-955: base measurement of test-issue-955-subagent-background-ban.sh at $BASE_REF (got base $BP955/$BT955, $BF955 failed)" \
        "base_measured \"$BP955\" \"$BT955\" \"$BF955\""
      assert_true "AC-59-11d-955: test-issue-955-subagent-background-ban.sh — 0 failed at HEAD, total not below base (got: $P955/$T955 vs base $BP955/$BT955)" \
        "base_measured \"$BP955\" \"$BT955\" \"$BF955\" && [ \"$F955\" -eq 0 ] && [ \"$T955\" -ge \"$BT955\" ]"
      assert_true "AC-59-21-test1: base measurement of test-issue-1-guard-contract.sh at $BASE_REF (got base $BPT1/$BTT1, $BFT1 failed)" \
        "base_measured \"$BPT1\" \"$BTT1\" \"$BFT1\""
      assert_true "AC-59-11d-test1: test-issue-1-guard-contract.sh (N1 aggregator) — 0 failed at HEAD, total not below base (got: $PT1/$TT1 vs base $BPT1/$BTT1)" \
        "base_measured \"$BPT1\" \"$BTT1\" \"$BFT1\" && [ \"$FT1\" -eq 0 ] && [ \"$TT1\" -ge \"$BTT1\" ]"

      # AC-59-18 reuses the 952/955 real re-runs above rather than invoking them a second
      # time (the manifest same-commit obligation's diff-membership fences live inside those
      # same suites — verification design §4 E9).
      assert_true "AC-59-18-955: 955 AC4-DOGFOOD (manifest-in-diff fence) does not regress the suite's own pass count" \
        "[ \"$F955\" -eq 0 ]"
      assert_true "AC-59-18-952: 952 AC5/AC5(T2) (manifest-in-diff + tests/plugin/ delegation) does not regress the suite's own pass count" \
        "[ \"$F952\" -eq 0 ]"
    fi
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

if [[ -z "$BASE_REF" ]]; then
  # 5 AC-59-21 preconditions + 5 AC-59-12c deltas (same accounting invariant as AC-59-11d).
  echo "  BLOCK: no comparison base resolvable — AC-59-21/AC-59-12c counted FAIL, never skipped"
  TESTS=$((TESTS + 10)); FAIL=$((FAIL + 10))
else
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

  # Same-environment baseline (ledger E33 — see suite_result_at_ref's header comment):
  # a literal count here has the identical host-dependence problem AC-59-11d had.
  read -r BP799W BT799W BF799W <<<"$(suite_result_at_ref "$BASE_REF" "test-issue-799-inert-cleanup.sh")"
  read -r BP798W BT798W BF798W <<<"$(suite_result_at_ref "$BASE_REF" "test-issue-798-topology-flip.sh")"
  read -r BP27W BT27W BF27W <<<"$(suite_result_at_ref "$BASE_REF" "test-issue-27-composition-oracle.sh")"
  read -r BP35W BT35W BF35W <<<"$(suite_result_at_ref "$BASE_REF" "test-issue-35-phase-marker.sh")"
  read -r BP56W BT56W BF56W <<<"$(suite_result_at_ref "$BASE_REF" "test-issue-56-carry-evidence-discipline.sh")"

  # Two counted assertions per lane, same shape as AC-59-11d above (D3).
  assert_true "AC-59-21-799W: base measurement of test-issue-799-inert-cleanup.sh at $BASE_REF (got base $BP799W/$BT799W, $BF799W failed)" \
    "base_measured \"$BP799W\" \"$BT799W\" \"$BF799W\""
  assert_true "AC-59-12c-799: test-issue-799-inert-cleanup.sh window (AC6-ci -A40) unaffected — 0 failed, total not below base (got: $P799W/$T799W vs base $BP799W/$BT799W)" \
    "base_measured \"$BP799W\" \"$BT799W\" \"$BF799W\" && [ \"$F799W\" -eq 0 ] && [ \"$T799W\" -ge \"$BT799W\" ]"
  assert_true "AC-59-21-798W: base measurement of test-issue-798-topology-flip.sh at $BASE_REF (got base $BP798W/$BT798W, $BF798W failed)" \
    "base_measured \"$BP798W\" \"$BT798W\" \"$BF798W\""
  assert_true "AC-59-12c-798: test-issue-798-topology-flip.sh window unaffected — 0 failed, total not below base (got: $P798W/$T798W vs base $BP798W/$BT798W)" \
    "base_measured \"$BP798W\" \"$BT798W\" \"$BF798W\" && [ \"$F798W\" -eq 0 ] && [ \"$T798W\" -ge \"$BT798W\" ]"
  assert_true "AC-59-21-27W: base measurement of test-issue-27-composition-oracle.sh at $BASE_REF (got base $BP27W/$BT27W, $BF27W failed)" \
    "base_measured \"$BP27W\" \"$BT27W\" \"$BF27W\""
  assert_true "AC-59-12c-27: test-issue-27-composition-oracle.sh window unaffected — 0 failed, total not below base (got: $P27W/$T27W vs base $BP27W/$BT27W)" \
    "base_measured \"$BP27W\" \"$BT27W\" \"$BF27W\" && [ \"$F27W\" -eq 0 ] && [ \"$T27W\" -ge \"$BT27W\" ]"
  assert_true "AC-59-21-35W: base measurement of test-issue-35-phase-marker.sh at $BASE_REF (got base $BP35W/$BT35W, $BF35W failed)" \
    "base_measured \"$BP35W\" \"$BT35W\" \"$BF35W\""
  assert_true "AC-59-12c-35: test-issue-35-phase-marker.sh (control) unaffected — 0 failed, total not below base (got: $P35W/$T35W vs base $BP35W/$BT35W)" \
    "base_measured \"$BP35W\" \"$BT35W\" \"$BF35W\" && [ \"$F35W\" -eq 0 ] && [ \"$T35W\" -ge \"$BT35W\" ]"
  assert_true "AC-59-21-56W: base measurement of test-issue-56-carry-evidence-discipline.sh at $BASE_REF (got base $BP56W/$BT56W, $BF56W failed)" \
    "base_measured \"$BP56W\" \"$BT56W\" \"$BF56W\""
  assert_true "AC-59-12c-56: test-issue-56-carry-evidence-discipline.sh (control) unaffected — 0 failed, total not below base (got: $P56W/$T56W vs base $BP56W/$BT56W)" \
    "base_measured \"$BP56W\" \"$BT56W\" \"$BF56W\" && [ \"$F56W\" -eq 0 ] && [ \"$T56W\" -ge \"$BT56W\" ]"
fi

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

CANON_LITERAL="$(grep -F 'AC-27-20c' "$CANON_SUITE" | grep -oE '\-eq [0-9]+ \]"$' | grep -oE '[0-9]+' | tail -1)"
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
echo ""
echo "=== AC-59-19a (unconditional, RED discriminator) — base_measured is the ONE place the sentinel is interpreted ==="

# Each reject-case condition is prefixed with a function-existence check
# (`declare -F base_measured`) before the negation. Without it, "base_measured: command not
# found" is a nonzero exit that `!` negates to true — the exact vacuous-PASS-on-unmeasured
# defect class this cycle exists to fix, now inside the guard's own RED test. The prefix makes
# the assertion FAIL loud today (function absent) and become a real negative check once GREEN
# defines the function.
assert_true "AC-59-19a-1: base_measured rejects the unmeasurable sentinel (-1 -1 -1)" \
  "declare -F base_measured >/dev/null && ! base_measured \"-1\" \"-1\" \"-1\""
assert_true "AC-59-19a-2: base_measured rejects a partial sentinel (-1 5 0)" \
  "declare -F base_measured >/dev/null && ! base_measured \"-1\" \"5\" \"0\""
assert_true "AC-59-19a-3: base_measured rejects a partial sentinel (5 -1 0)" \
  "declare -F base_measured >/dev/null && ! base_measured \"5\" \"-1\" \"0\""
assert_true "AC-59-19a-4: base_measured rejects a partial sentinel (5 5 -1)" \
  "declare -F base_measured >/dev/null && ! base_measured \"5\" \"5\" \"-1\""
assert_true "AC-59-19a-5: base_measured rejects an empty field (what read produces on empty output)" \
  "declare -F base_measured >/dev/null && ! base_measured \"\" \"5\" \"0\""
assert_true "AC-59-19a-6: base_measured accepts a real CI shape with p<t, an environment-conditional sub-test not registering (15 18 0)" \
  "base_measured \"15\" \"18\" \"0\""
assert_true "AC-59-19a-7: base_measured accepts a positive control (5 5 0)" \
  "base_measured \"5\" \"5\" \"0\""

# =============================================================================
echo ""
echo "=== AC-59-19b (unconditional, RED discriminator, self-scoped structural grep) — no delta comparison bypasses the guard ==="

# The pattern literal is split across quote boundaries so this definition line cannot itself
# satisfy the pattern it defines (self-scoping, matching the file's existing structural
# assertions' convention). Quote-agnostic (M12): the 12 conditions live inside assert_true's
# quoted argument, so their source has a backslash-escaped quote (\"$BT...\"), but the pattern
# also accepts a bare quote.
DELTA_GE_PATTERN='-ge'" +"'\\?"\$BT'
DELTA_GE_LINE_COUNT="$(grep -cE -- "$DELTA_GE_PATTERN" "${BASH_SOURCE[0]}" || true)"
DELTA_GE_GUARDED_COUNT="$(grep -E -- "$DELTA_GE_PATTERN" "${BASH_SOURCE[0]}" | grep -c 'base_measured' || true)"

assert_true "AC-59-19b-total: exactly 12 delta conditions compare -ge against a base total field (got: $DELTA_GE_LINE_COUNT)" \
  "[ \"$DELTA_GE_LINE_COUNT\" -eq 12 ]"
assert_true "AC-59-19b-guarded: all 12 of those conditions also carry a base_measured conjunct on the same line — zero bypass the guard (got: $DELTA_GE_GUARDED_COUNT of $DELTA_GE_LINE_COUNT)" \
  "[ \"$DELTA_GE_GUARDED_COUNT\" -eq 12 ]"

# =============================================================================
echo ""
echo "=== AC-59-20a (unconditional, characterization) — the worktree-add failure path is reachable via real git ==="

read -r P20A T20A F20A <<<"$(suite_result_at_ref 'refs/heads/__autoflow-issue59-nonexistent__' 'test-issue-35-phase-marker.sh')"
assert_true "AC-59-20a: suite_result_at_ref returns the unmeasurable sentinel for an unresolvable ref, real git (got: $P20A $T20A $F20A)" \
  "[ \"$P20A\" = \"-1\" ] && [ \"$T20A\" = \"-1\" ] && [ \"$F20A\" = \"-1\" ]"

# =============================================================================
echo ""
echo "=== AC-59-20b (unconditional, characterization) — the Results:-less parse path returns the sentinel ==="

read -r P20B T20B F20B <<<"$(suite_counts 'no Results line in this output')"
assert_true "AC-59-20b: suite_counts returns the unmeasurable sentinel when no Results: line is present (got: $P20B $T20B $F20B)" \
  "[ \"$P20B\" = \"-1\" ] && [ \"$T20B\" = \"-1\" ] && [ \"$F20B\" = \"-1\" ]"

# =============================================================================
echo ""
echo "=== AC-59-20c (unconditional, RED discriminator) — real suite_result_at_ref composed with real base_measured ==="

read -r P20C1 T20C1 F20C1 <<<"$(suite_result_at_ref 'refs/heads/__autoflow-issue59-nonexistent__' 'test-issue-35-phase-marker.sh')"
assert_true "AC-59-20c-reject: base_measured rejects the real suite_result_at_ref output for an unmeasurable base (got: $P20C1 $T20C1 $F20C1)" \
  "declare -F base_measured >/dev/null && ! base_measured \"$P20C1\" \"$T20C1\" \"$F20C1\""

read -r P20C2 T20C2 F20C2 <<<"$(suite_counts 'Results: 15/18 passed, 0 failed')"
assert_true "AC-59-20c-accept: base_measured accepts the real suite_counts output for a measured base (got: $P20C2 $T20C2 $F20C2)" \
  "base_measured \"$P20C2\" \"$T20C2\" \"$F20C2\""

# =============================================================================
echo ""
echo "=== AC-59-22a (unconditional, RED discriminator, self-scoped structural grep) — precondition/delta labels are separately attributable ==="

# Split literals so this definition cannot match itself (same self-scoping convention as
# AC-59-19b above).
PRECOND_LABEL_PATTERN='assert_true "AC-59-21'"-"
DELTA_11D_LABEL_PATTERN='assert_true "AC-59-11d'"-"
DELTA_12C_LABEL_PATTERN='assert_true "AC-59-12c'"-"

PRECOND_LABEL_COUNT="$(grep -cE "$PRECOND_LABEL_PATTERN" "${BASH_SOURCE[0]}" || true)"
DELTA_LABEL_COUNT="$(( $(grep -cE "$DELTA_11D_LABEL_PATTERN" "${BASH_SOURCE[0]}" || true) + $(grep -cE "$DELTA_12C_LABEL_PATTERN" "${BASH_SOURCE[0]}" || true) ))"
CLAIM_SHAPED_PRECOND="$(grep -E "$PRECOND_LABEL_PATTERN" "${BASH_SOURCE[0]}" | grep -cE 'succeeded|not below' || true)"

assert_true "AC-59-22a: 12 base-precondition labels and 12 delta labels exist, each naming its suite, and no precondition label carries a claim-shaped verb that would invert under FAIL: (got: precond=$PRECOND_LABEL_COUNT, delta=$DELTA_LABEL_COUNT, claim-shaped=$CLAIM_SHAPED_PRECOND)" \
  "[ \"$PRECOND_LABEL_COUNT\" -eq 12 ] && [ \"$DELTA_LABEL_COUNT\" -eq 12 ] && [ \"$CLAIM_SHAPED_PRECOND\" -eq 0 ]"

# =============================================================================
echo ""
echo "=== AC-59-22b (unconditional, RED discriminator) — every precondition label interpolates the base failed count ==="

BF_INTERP_COUNT="$(grep -E "$PRECOND_LABEL_PATTERN" "${BASH_SOURCE[0]}" | grep -cE '\$BF[0-9A-Za-z]*' || true)"
assert_true "AC-59-22b: all 12 base-precondition labels interpolate \$BF... (base failed count) alongside \$BP.../\$BT... (got: $BF_INTERP_COUNT of 12)" \
  "[ \"$BF_INTERP_COUNT\" -eq 12 ]"

# =============================================================================
# Cycle 3 (review-response) — AC-59-25 … AC-59-35 (AC-59-30 retired, AC-59-33
# is a regression-fence procedure, not a lane; see header comment).
# =============================================================================
# Route (iv) (verification design cycle-3 §1): every lane below copies the
# REAL tests/issue-59-full-sweep-driver.sh byte-for-byte into a throwaway
# `git init` fixture repo and runs it AS A PROGRAM — never a re-typed copy of
# its logic. `require_copy_fidelity` asserts the copy immediately before each
# run (AC-59-35b(i)).
#
# GATE:PLAN carry-note (ledger E48): every condition below uses bash-native
# `[[ ... ]]` string matching (the `has`/`has_not` helpers) instead of
# `identifier | grep -q` / `| grep -m` — a captured string has no concurrent
# producer process, so the SIGPIPE race tests/test-issue-964-sigpipe-safe-pipes.sh
# guards against cannot occur here, and this suite's own additions cannot
# widen that guard's zero-remaining hazard-shape count (AC-59-33 extension).

DRIVER_SRC="$PROJECT_ROOT/tests/issue-59-full-sweep-driver.sh"

has() { [[ "$1" == *"$2"* ]]; }

mk_fixture_repo() {
  local fx
  fx="$(mktemp -d)"
  git -C "$fx" init -q >/dev/null 2>&1
  git -C "$fx" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init >/dev/null 2>&1
  printf '%s' "$fx"
}

# commit_fixture_suite <fx> <suite-basename> <exit-code> <commit-message>
commit_fixture_suite() {
  local fx="$1" name="$2" code="$3" msg="$4"
  mkdir -p "$fx/tests"
  printf '#!/usr/bin/env bash\nexit %s\n' "$code" >"$fx/tests/$name"
  chmod +x "$fx/tests/$name"
  git -C "$fx" add "tests/$name" >/dev/null 2>&1
  git -C "$fx" -c user.email=t@t -c user.name=t commit -q -m "$msg" >/dev/null 2>&1
}

install_driver_copy() {
  local fx="$1"
  mkdir -p "$fx/tests"
  cp "$DRIVER_SRC" "$fx/tests/issue-59-full-sweep-driver.sh"
}

COPY_FIDELITY_CHECKS=0
COPY_FIDELITY_FAILS=0
require_copy_fidelity() {
  local fx="$1"
  COPY_FIDELITY_CHECKS=$((COPY_FIDELITY_CHECKS + 1))
  cmp -s "$DRIVER_SRC" "$fx/tests/issue-59-full-sweep-driver.sh" || COPY_FIDELITY_FAILS=$((COPY_FIDELITY_FAILS + 1))
}

# NAMED_SUITES parsed from the LIVE driver source (never a pinned literal
# copy — the array is cycle-scoped by its own comment) so rows (c)/(d) below
# track the live array (verification design cycle-3 §1, AC-59-27 note).
mapfile -t NAMED_SUITES_LIVE < <(awk '/^NAMED_SUITES=\(/,/^\)/' "$DRIVER_SRC" | grep -oE '"[^"]+"' | tr -d '"')
NAMED0="${NAMED_SUITES_LIVE[0]:-}"
UNNAMED_PROBE_IN_NAMED=0
for _n in "${NAMED_SUITES_LIVE[@]}"; do [[ "$_n" == "test-issue-777-fixture.sh" ]] && UNNAMED_PROBE_IN_NAMED=1; done

# =============================================================================
echo ""
echo "=== AC-59-25 (cycle 3, RED discriminator) — unmeasured base is never reported as ALREADY RED ==="

FX25="$(mk_fixture_repo)"
commit_fixture_suite "$FX25" test-issue-777-fixture.sh 0 base
commit_fixture_suite "$FX25" test-issue-777-fixture.sh 1 head
install_driver_copy "$FX25"
require_copy_fidelity "$FX25"
OUT25="$(cd "$FX25" && bash tests/issue-59-full-sweep-driver.sh 'refs/heads/__autoflow-issue59-c3-nonexistent__' 2>&1)"
rm -rf "$FX25"

assert_true "AC-59-25: an unresolvable base ref is reported as per-suite INCONCLUSIVE (naming the suite + the real git worktree add exit status), never a fabricated ALREADY RED, and buckets 0 clean/already-red + 1 inconclusive" \
  "has \"\$OUT25\" 'INCONCLUSIVE: base worktree setup failed' && has \"\$OUT25\" 'test-issue-777-fixture.sh' && has \"\$OUT25\" 'git worktree add exit' && ! has \"\$OUT25\" 'ALREADY RED on' && has \"\$OUT25\" 'Clean/already-red: 0' && has \"\$OUT25\" 'Inconclusive (base never measured): 1'"

# =============================================================================
echo ""
echo "=== AC-59-26 (cycle 3, RED discriminator) — suite absent at a resolvable base gets an honest label, never ALREADY RED ==="

FX26="$(mk_fixture_repo)"
BASE26_SHA="$(git -C "$FX26" rev-parse HEAD)"
commit_fixture_suite "$FX26" test-issue-777-fixture.sh 1 head-adds-new-red-suite
install_driver_copy "$FX26"
require_copy_fidelity "$FX26"
OUT26="$(cd "$FX26" && bash tests/issue-59-full-sweep-driver.sh "$BASE26_SHA" 2>&1)"
rm -rf "$FX26"

assert_true "AC-59-26: a suite absent at a resolvable base is labelled NEW AT HEAD, never ALREADY RED, and is not counted inconclusive (nothing failed — the base measurement never runs)" \
  "has \"\$OUT26\" 'NEW AT HEAD:' && has \"\$OUT26\" 'test-issue-777-fixture.sh' && ! has \"\$OUT26\" 'ALREADY RED on' && has \"\$OUT26\" 'Inconclusive (base never measured): 0'"

# =============================================================================
echo ""
echo "=== AC-59-27 (cycle 3, characterization, four shapes) — every pre-existing verdict survives byte-identical ==="

FX27A="$(mk_fixture_repo)"
commit_fixture_suite "$FX27A" test-issue-777-fixture.sh 0 base
commit_fixture_suite "$FX27A" test-issue-777-fixture.sh 0 head-still-green
install_driver_copy "$FX27A"
require_copy_fidelity "$FX27A"
OUT27A="$(cd "$FX27A" && bash tests/issue-59-full-sweep-driver.sh 'refs/heads/__autoflow-issue59-c3-nonexistent2__' 2>&1)"
rm -rf "$FX27A"
assert_true "AC-59-27a: a green-at-HEAD suite stays clean even when its base is unmeasurable — an unresolvable base must not manufacture an inconclusive" \
  "has \"\$OUT27A\" 'clean (exit 0)' && has \"\$OUT27A\" 'Clean/already-red: 1' && has \"\$OUT27A\" 'Inconclusive (base never measured): 0'"

FX27B="$(mk_fixture_repo)"
commit_fixture_suite "$FX27B" test-issue-777-fixture.sh 1 base-red
BASE27B_SHA="$(git -C "$FX27B" rev-parse HEAD)"
commit_fixture_suite "$FX27B" test-issue-777-fixture.sh 1 head-still-red
install_driver_copy "$FX27B"
require_copy_fidelity "$FX27B"
OUT27B="$(cd "$FX27B" && bash tests/issue-59-full-sweep-driver.sh "$BASE27B_SHA" 2>&1)"
rm -rf "$FX27B"
assert_true "AC-59-27b: a genuinely measured red base is still classified ALREADY RED — the guard does not over-flag a real measured-red base as inconclusive" \
  "has \"\$OUT27B\" 'ALREADY RED on' && has \"\$OUT27B\" 'Inconclusive (base never measured): 0'"

FX27C="$(mk_fixture_repo)"
commit_fixture_suite "$FX27C" "$NAMED0" 0 base-green
BASE27C_SHA="$(git -C "$FX27C" rev-parse HEAD)"
commit_fixture_suite "$FX27C" "$NAMED0" 1 head-red
install_driver_copy "$FX27C"
require_copy_fidelity "$FX27C"
OUT27C="$(cd "$FX27C" && bash tests/issue-59-full-sweep-driver.sh "$BASE27C_SHA" 2>&1)"
rm -rf "$FX27C"
assert_true "AC-59-27c: a named regression ($NAMED0, element 0 of the live NAMED_SUITES array) is bucketed REGRESSED (named), never unnamed" \
  "[ -n \"$NAMED0\" ] && has \"\$OUT27C\" 'REGRESSED (named'"

FX27D="$(mk_fixture_repo)"
commit_fixture_suite "$FX27D" test-issue-777-fixture.sh 0 base-green
BASE27D_SHA="$(git -C "$FX27D" rev-parse HEAD)"
commit_fixture_suite "$FX27D" test-issue-777-fixture.sh 1 head-red
install_driver_copy "$FX27D"
require_copy_fidelity "$FX27D"
OUT27D="$(cd "$FX27D" && bash tests/issue-59-full-sweep-driver.sh "$BASE27D_SHA" 2>&1)"
rm -rf "$FX27D"
assert_true "AC-59-27d: an unnamed regression (test-issue-777-fixture.sh, confirmed absent from the live NAMED_SUITES array: in_named=$UNNAMED_PROBE_IN_NAMED) is bucketed REGRESSED (UNNAMED and drives Unnamed regressions (NEW finding): 1" \
  "[ \"$UNNAMED_PROBE_IN_NAMED\" -eq 0 ] && has \"\$OUT27D\" 'REGRESSED (UNNAMED' && has \"\$OUT27D\" 'Unnamed regressions (NEW finding): 1'"

# =============================================================================
echo ""
echo "=== AC-59-28 (cycle 3, RED discriminator, self-scoped structural grep) — base-exit is never fabricated, ALREADY RED has one home ==="

# Split literals so these definitions cannot match themselves (same self-scoping
# convention as AC-59-19b/22a above); scanned over the DRIVER, not this file.
BASE_EXIT_CMP_PATTERN='base_exit'" "'-ne'
BASE_EXIT_CMP_COUNT="$(grep -cE -- "$BASE_EXIT_CMP_PATTERN" "$DRIVER_SRC" || true)"
BASE_EXIT_GUARDED_COUNT="$(grep -E -- "$BASE_EXIT_CMP_PATTERN" "$DRIVER_SRC" | grep -c 'base_measured' || true)"
BASE_EXIT_SEED_LITERAL_COUNT="$(grep -cE 'base_exit=[0-9]{1,3}$' "$DRIVER_SRC" || true)"
ALREADY_RED_VERDICT_PATTERN='ALREADY'" "'RED on'
ALREADY_RED_VERDICT_COUNT="$(grep -cE -- "$ALREADY_RED_VERDICT_PATTERN" "$DRIVER_SRC" || true)"
INCONCLUSIVE_PER_SUITE_COUNT="$(grep -cE 'INCONCLUSIVE: base worktree setup failed' "$DRIVER_SRC" || true)"
INCONCLUSIVE_NO_BASE_COUNT="$(grep -cE 'INCONCLUSIVE: no comparison base resolvable' "$DRIVER_SRC" || true)"
INCONCLUSIVE_ELAPSED_COUNT="$(grep -cE 'INCONCLUSIVE: elapsed' "$DRIVER_SRC" || true)"

assert_true "AC-59-28: base-exit comparisons are all measured-guarded (guarded=$BASE_EXIT_GUARDED_COUNT of $BASE_EXIT_CMP_COUNT), the seed is never a literal 0-255 exit status (got $BASE_EXIT_SEED_LITERAL_COUNT), the ALREADY RED verdict form has exactly one home (got $ALREADY_RED_VERDICT_COUNT), and the per-suite INCONCLUSIVE label is distinct from both script-level INCONCLUSIVE exits (per-suite=$INCONCLUSIVE_PER_SUITE_COUNT, no-base=$INCONCLUSIVE_NO_BASE_COUNT, elapsed=$INCONCLUSIVE_ELAPSED_COUNT)" \
  "[ \"$BASE_EXIT_CMP_COUNT\" -ge 1 ] && [ \"$BASE_EXIT_GUARDED_COUNT\" -eq \"$BASE_EXIT_CMP_COUNT\" ] && [ \"$BASE_EXIT_SEED_LITERAL_COUNT\" -eq 0 ] && [ \"$ALREADY_RED_VERDICT_COUNT\" -eq 1 ] && [ \"$INCONCLUSIVE_PER_SUITE_COUNT\" -ge 1 ] && [ \"$INCONCLUSIVE_NO_BASE_COUNT\" -eq 1 ] && [ \"$INCONCLUSIVE_ELAPSED_COUNT\" -eq 1 ]"

# =============================================================================
echo ""
echo "=== AC-59-29 (cycle 3, RED discriminator) — run-level exit code: never PASS(0) while unmeasured; FAIL(1) outranks INCONCLUSIVE(2); default budget stays 600s ==="

# Shape 1 (clean): PINNED TO A RESOLVABLE BASE SHA (GATE:PLAN carry-note,
# ledger E48) — a genuinely successful `git worktree add` + base run, not the
# unresolvable-ref shortcut AC-59-27a already covers.
FX29C="$(mk_fixture_repo)"
commit_fixture_suite "$FX29C" test-issue-777-fixture.sh 0 base-green
BASE29C_SHA="$(git -C "$FX29C" rev-parse HEAD)"
commit_fixture_suite "$FX29C" test-issue-777-fixture.sh 0 head-still-green
install_driver_copy "$FX29C"
require_copy_fidelity "$FX29C"
(cd "$FX29C" && SWEEP_MIN_ELAPSED=0 bash tests/issue-59-full-sweep-driver.sh "$BASE29C_SHA" >/dev/null 2>&1)
RC29C=$?
rm -rf "$FX29C"

# Shape 2 (inconclusive-only, AC-59-25's shape).
FX29I="$(mk_fixture_repo)"
commit_fixture_suite "$FX29I" test-issue-777-fixture.sh 0 base
commit_fixture_suite "$FX29I" test-issue-777-fixture.sh 1 head
install_driver_copy "$FX29I"
require_copy_fidelity "$FX29I"
(cd "$FX29I" && SWEEP_MIN_ELAPSED=0 bash tests/issue-59-full-sweep-driver.sh 'refs/heads/__autoflow-issue59-c3-nonexistent3__' >/dev/null 2>&1)
RC29I=$?
rm -rf "$FX29I"

# Shape 3 (unnamed-regression-only, AC-59-27d's shape).
FX29U="$(mk_fixture_repo)"
commit_fixture_suite "$FX29U" test-issue-777-fixture.sh 0 base-green
BASE29U_SHA="$(git -C "$FX29U" rev-parse HEAD)"
commit_fixture_suite "$FX29U" test-issue-777-fixture.sh 1 head-red
install_driver_copy "$FX29U"
require_copy_fidelity "$FX29U"
(cd "$FX29U" && SWEEP_MIN_ELAPSED=0 bash tests/issue-59-full-sweep-driver.sh "$BASE29U_SHA" >/dev/null 2>&1)
RC29U=$?
rm -rf "$FX29U"

# Shape 5 (default-preservation): the clean shape re-run WITHOUT
# SWEEP_MIN_ELAPSED — pins that the unexported default stays 600s.
FX29D="$(mk_fixture_repo)"
commit_fixture_suite "$FX29D" test-issue-777-fixture.sh 0 base-green
BASE29D_SHA="$(git -C "$FX29D" rev-parse HEAD)"
commit_fixture_suite "$FX29D" test-issue-777-fixture.sh 0 head-still-green
install_driver_copy "$FX29D"
require_copy_fidelity "$FX29D"
(cd "$FX29D" && bash tests/issue-59-full-sweep-driver.sh "$BASE29D_SHA" >/dev/null 2>&1)
RC29D=$?
rm -rf "$FX29D"

assert_true "AC-59-29 (behavioural): real driver exit code — clean+resolvable-base -> 0 (got $RC29C), inconclusive-only -> 2 (got $RC29I), unnamed-regression-only -> 1 (got $RC29U), clean without the SWEEP_MIN_ELAPSED override still -> 2 under the unchanged 600s default (got $RC29D)" \
  "[ \"$RC29C\" -eq 0 ] && [ \"$RC29I\" -eq 2 ] && [ \"$RC29U\" -eq 1 ] && [ \"$RC29D\" -eq 2 ]"

FAIL_GATE_LINE="$(grep -nF 'FAIL: unnamed regression(s) found' "$DRIVER_SRC" | head -1 | cut -d: -f1)"
INCONCLUSIVE_BUCKET_GATE_LINE="$(grep -nF 'suite(s) never measured' "$DRIVER_SRC" | head -1 | cut -d: -f1)"
SUMMARY_BLOCK_LINE="$(grep -nF 'Clean/already-red:' "$DRIVER_SRC" | head -1 | cut -d: -f1)"
assert_true "AC-59-29 (P): the FAIL(unnamed-regression) exit gate's anchor precedes the run-level INCONCLUSIVE-bucket exit gate's anchor, both after the summary block (FAIL=${FAIL_GATE_LINE:-absent}, INCONCLUSIVE-bucket=${INCONCLUSIVE_BUCKET_GATE_LINE:-absent}, summary=${SUMMARY_BLOCK_LINE:-absent})" \
  "[ -n \"$FAIL_GATE_LINE\" ] && [ -n \"$INCONCLUSIVE_BUCKET_GATE_LINE\" ] && [ -n \"$SUMMARY_BLOCK_LINE\" ] && [ \"$SUMMARY_BLOCK_LINE\" -lt \"$FAIL_GATE_LINE\" ] && [ \"$FAIL_GATE_LINE\" -lt \"$INCONCLUSIVE_BUCKET_GATE_LINE\" ]"

BUDGET_DEFAULT_PATTERN='SWEEP_MIN_ELAPSED:-'"6"'00'
BUDGET_DEFAULT_COUNT="$(grep -cE -- "$BUDGET_DEFAULT_PATTERN" "$DRIVER_SRC" || true)"
assert_true "AC-59-29 (D): the sweep budget's :--defaulted assignment exists with default operand exactly 600 (got $BUDGET_DEFAULT_COUNT)" \
  "[ \"$BUDGET_DEFAULT_COUNT\" -eq 1 ]"

# =============================================================================
echo ""
echo "=== AC-59-31 (cycle 3, characterization) — standalone execution against the LIVE tree is preserved ==="

OUT31="$(cd "$PROJECT_ROOT" && timeout 10 bash tests/issue-59-full-sweep-driver.sh '__autoflow-issue59-c3-nonexistent4__' 2>&1 | head -3)"
BASH_N_31=0
bash -n "$DRIVER_SRC" && BASH_N_31=1
WT_COUNT_31_AFTER="$(git -C "$PROJECT_ROOT" worktree list | wc -l | tr -d ' ')"
assert_true "AC-59-31: standalone execution against the live tree still prints its banner + self-exclusion notice before entering the suite loop, bash -n stays clean (got $BASH_N_31), and no worktree residue is left (worktree-count-after=$WT_COUNT_31_AFTER)" \
  "has \"\$OUT31\" 'Full-tree sweep driver (issue #59, D24) — base: __autoflow-issue59-c3-nonexistent4__' && has \"\$OUT31\" 'Self-excluding:' && [ \"$BASH_N_31\" -eq 1 ] && [ \"$WT_COUNT_31_AFTER\" -eq 1 ]"

# =============================================================================
echo ""
echo "=== AC-59-32 (cycle 3, RED discriminator) — no temp-directory leak on the failure path ==="

SANDBOX32="$(mktemp -d)"
FX32="$(mk_fixture_repo)"
commit_fixture_suite "$FX32" test-issue-777-fixture.sh 0 base
commit_fixture_suite "$FX32" test-issue-777-fixture.sh 1 head
install_driver_copy "$FX32"
require_copy_fidelity "$FX32"
(cd "$FX32" && TMPDIR="$SANDBOX32" bash tests/issue-59-full-sweep-driver.sh 'refs/heads/__autoflow-issue59-c3-nonexistent5__' >/dev/null 2>&1)
LEAK_COUNT_32="$(ls -Ad "$SANDBOX32"/autoflow-sweep-wt.* 2>/dev/null | wc -l | tr -d ' ')"
rm -rf "$FX32" "$SANDBOX32"
assert_true "AC-59-32: the failed-add path leaves zero autoflow-sweep-wt.* directories under the TMPDIR-honouring sandbox (got $LEAK_COUNT_32) — sound only once the driver allocates via mktemp -d \"\${TMPDIR:-/tmp}/autoflow-sweep-wt.XXXXXX\"; pre-fix, bare mktemp -d does not honour TMPDIR on this host, so this count is a CHARACTERIZATION pre-fix, not a discriminator (recorded in the RED report)" \
  "[ \"$LEAK_COUNT_32\" -eq 0 ]"

# =============================================================================
echo ""
echo "=== AC-59-35 (cycle 3, characterization) — the LIVE repository's worktree channel is driven for real, and left unchanged ==="

WT_COUNT_35_BEFORE="$(git -C "$PROJECT_ROOT" worktree list | wc -l | tr -d ' ')"
WT35="$(mktemp -d)"
git -C "$PROJECT_ROOT" worktree add -q --detach "$WT35" 'refs/heads/__autoflow-issue59-c3-nonexistent6__' >/dev/null 2>&1
RC35=$?
rm -rf "$WT35"
WT_COUNT_35_AFTER="$(git -C "$PROJECT_ROOT" worktree list | wc -l | tr -d ' ')"
assert_true "AC-59-35: a single failed live git worktree add against THIS repository returns a non-zero status (got $RC35) and leaves the live worktree registry unchanged (before=$WT_COUNT_35_BEFORE, after=$WT_COUNT_35_AFTER)" \
  "[ \"$RC35\" -ne 0 ] && [ \"$WT_COUNT_35_BEFORE\" -eq \"$WT_COUNT_35_AFTER\" ]"

# =============================================================================
echo ""
echo "=== AC-59-35b (cycle 3, fixture-hygiene fences) — every harness-F lane exercised the real driver, nothing outside the fixtures was mutated ==="

WT_COUNT_35B_AFTER="$(git -C "$PROJECT_ROOT" worktree list | wc -l | tr -d ' ')"
STATUS_35B_AFTER="$(git -C "$PROJECT_ROOT" status --short)"
assert_true "AC-59-35b(i): copy fidelity held immediately before every one of this cycle's harness-F fixture runs (checks=$COPY_FIDELITY_CHECKS, fails=$COPY_FIDELITY_FAILS)" \
  "[ \"$COPY_FIDELITY_CHECKS\" -eq 11 ] && [ \"$COPY_FIDELITY_FAILS\" -eq 0 ]"
assert_true "AC-59-35b(ii): after every cycle-3 fixture lane the live repo still has exactly one worktree entry and an empty status (worktree-count=$WT_COUNT_35B_AFTER)" \
  "[ \"$WT_COUNT_35B_AFTER\" -eq 1 ] && [ -z \"$STATUS_35B_AFTER\" ]"

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
