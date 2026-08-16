#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/workflows/architect-deliberation.js .claude/workflows/verify-cause-branch.js .github/workflows/e2e-dummy-target.yml docs/doc-invariant-registry.md scripts/test/check-suite-ci-coverage.sh scripts/test/run-suites.sh scripts/test/select-suites.sh setup/manifest.json test/workflows/run.mjs tests/fixtures/doc-invariants.json tests/lib/base-ref.sh tests/lib/harness-pins.sh tests/manual/issue-59-manual-scenarios.md tests/run-doc-invariants.sh
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
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
#                never the `const carry = register.size` ternary line
#                (re-anchored by issue #67, which retargets the carry from
#                `openCounters` to the issue register).
#   AC-59-8c   — #56's own constant counts are byte-immutable (D4).
#   AC-59-8d   — round-prompt insertion ORDER: `${COUNTER_EVIDENCE_RULE}${ADOPTION_EVIDENCE_RULE}`
#                immediately followed by `${carry}` at the tail, unbroken until issue #67
#                inserted `${REGISTER_RULE}${RECORD_DISCIPLINE_RULE}` between
#                ADOPTION_EVIDENCE_RULE and carry (feature design §2.5: both new
#                round-prompt-scoped constants). Re-anchored, not dropped: the surviving
#                intent — COUNTER_EVIDENCE_RULE before ADOPTION_EVIDENCE_RULE, both before
#                the carry-bearing tail — still holds; only the two new record-rule
#                constants now sit between ADOPTION_EVIDENCE_RULE and carry.
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
#   AC-59-14   — RED discriminator + fence: the shared harness ok-count pin
#                (tests/test-issue-27-composition-oracle.sh:328) is bumped to
#                43 in the same commit as C4, and the two pins (that literal
#                and this suite's own EXPECTED_OK) agree (cross-pin equality,
#                D18).
#   AC-59-15(a) — RED discriminator (branch-scoped): the re-run oracles above
#                are measured against a NON-EMPTY diff containing this
#                cycle's own change surface — a re-run against an empty diff
#                (B11) proves nothing.
#   AC-59-16   — fence (unconditional): the two adjacent negative-control pins
#                (manifest artifact count 47; the derived pre-existing
#                registry total) are untouched by this cycle's additions.
#   AC-59-18   — fence (unconditional): the manifest same-commit obligation
#                holds against all three of its fences (AC-56-10a, 955's
#                AC4-DOGFOOD, 952's AC5/AC5(T2)).
#
# --- cycle 2 (review-response, codex Medium: unguarded -1/-1/-1 sentinel) ---
#   AC-59-19a  — unconditional, RED discriminator: `base_measured` is the ONE
#                place the sentinel is interpreted (7-row table).
#   AC-59-19b  — unconditional, RED discriminator, self-scoped structural grep:
#                no delta comparison bypasses the guard (7 `-ge $BT...`
#                conditions, all 7 also carry a `base_measured` conjunct).
#   AC-59-20a  — unconditional, characterization: the worktree-add failure
#                path is reachable via real git and returns the sentinel.
#   AC-59-20b  — unconditional, characterization: the Results:-less parse path
#                returns the sentinel.
#   AC-59-20c  — unconditional, RED discriminator: the real `suite_result_at_ref`
#                composed with the real `base_measured`, no re-typed copy.
#   AC-59-21   — branch-scoped: each of the 7 AC-59-11d lanes gets a
#                separate base-measurement precondition assertion, plus the
#                `base_measured` conjunct leading its own delta condition.
#   AC-59-22a  — unconditional, RED discriminator, self-scoped structural grep:
#                7 precondition labels + 7 delta labels exist, each naming
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

# EXPECTED_OK: issue #103 single-sourced the pin. It had two authored homes — this
# literal and tests/test-issue-27-composition-oracle.sh's — plus a cross-pin
# agreement check whose entire subject was keeping them synchronised. The literal
# now lives once, in tests/lib/harness-pins.sh, and both consumers read it, so a
# harness change is one deliberate edit rather than a synchronised bump.
# shellcheck source=tests/lib/harness-pins.sh
source "$PROJECT_ROOT/tests/lib/harness-pins.sh"
EXPECTED_OK="$HARNESS_OK_COUNT"

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
# Ledger E33 (PR #61, CI run 31088600592): the delta lanes originally pinned literal
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
CARRY_TERNARY_SITE="$(grep '\${ADOPTION_EVIDENCE_RULE}' "$WORKFLOW_JS" | grep -c 'const carry = register.size' || true)"

assert_true "AC-59-8b-dev-draft: exactly one interpolation line matches the dev-draft prompt prefix (got: $DEV_DRAFT_SITE)" \
  "[ \"$DEV_DRAFT_SITE\" -eq 1 ]"
assert_true "AC-59-8b-test-draft: exactly one interpolation line matches the test-draft prompt prefix (got: $TEST_DRAFT_SITE)" \
  "[ \"$TEST_DRAFT_SITE\" -eq 1 ]"
assert_true "AC-59-8b-dev-round: exactly one interpolation line matches the dev-round prompt prefix (got: $DEV_ROUND_SITE)" \
  "[ \"$DEV_ROUND_SITE\" -eq 1 ]"
assert_true "AC-59-8b-test-round: exactly one interpolation line matches the test-round prompt prefix (got: $TEST_ROUND_SITE)" \
  "[ \"$TEST_ROUND_SITE\" -eq 1 ]"
assert_true "AC-59-8b-unconditional: zero interpolation occurrences sit on the carry ternary line (re-anchored, issue #67 AC19) (got: $CARRY_TERNARY_SITE)" \
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

ORDER_COUNT="$(grep -c '\${COUNTER_EVIDENCE_RULE}\${ADOPTION_EVIDENCE_RULE}\${REGISTER_RULE}\${RECORD_DISCIPLINE_RULE}\${carry}' "$WORKFLOW_JS" || true)"
assert_true "AC-59-8d: the contiguous sequence \${COUNTER_EVIDENCE_RULE}\${ADOPTION_EVIDENCE_RULE}\${REGISTER_RULE}\${RECORD_DISCIPLINE_RULE}\${carry} occurs exactly 2 times (re-anchored, issue #67 §2.5) (got: $ORDER_COUNT)" \
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
# AC-59-11d / AC-59-21 / AC-59-18 are retired by issue #103's leaf rule.
# =============================================================================
# The lane re-ran six sibling suites at HEAD and again at the comparison base to
# compare their totals. Each of those six carries its own `run:` step, so the
# HEAD half was duplicate execution of an already-covered surface, and with it
# the base half loses the delta it was the other side of.
#
# The property the lane protected — a cross-cycle guard must not lose assertions
# — is carried structurally instead: scripts/test/check-suite-ci-coverage.sh
# proves every suite still has an execution path, and each suite's own CI step
# reports its own failure under its own name.

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
# AC-59-14 (a1 / a2 / a3-stale-label / a3-new-label / c) is retired by issue #103.
# =============================================================================
# The block asserted one cycle's BUMP DISCIPLINE: that a harness change bumped
# both foreign pin homes in the same commit, and that no stale literal survived.
# Single-sourcing the pin into tests/lib/harness-pins.sh leaves no foreign home
# and no synchronised bump, so the subject of the assertion no longer exists;
# the staleness half would be vacuously true over a literal that is gone, which
# is the vacuous-PASS class this tree removes rather than keeps.
#
# What survives moves: ONE AUTHORING HOME is asserted by
# scripts/test/check-suite-manifest.sh's single-authorship arm, and THE PIN
# STILL DETECTS by tests/test-issue-27-composition-oracle.sh comparing the
# sourced constant against the live `node test/workflows/run.mjs` measurement.
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

# AC-59-16a was a global artifact-count fence (== 47) — the retired
# ADR-0016 AC-R3-c count-guard class (docs/doc-invariant-registry.md:113),
# same defect the registry's own row for this class documents at
# docs/doc-invariant-registry.md:114 (test-issue-27-composition-oracle.sh
# AC-27-21a, reddened by issue #51's ADR-0017 manifest row, 47 -> 48).
# Converted to the drift-immune shape used there: a state predicate over the
# single named source this suite's own AC-59-9 pins manifest-hash freshness
# for (architect-deliberation.js), not a global count.
ARTIFACT_COUNT="$(jq '.artifacts | length' "$MANIFEST")"
echo "  (info) AC-59-16a: setup/manifest.json artifact count is currently $ARTIFACT_COUNT (informational — not asserted; see conversion note above)"

AC_59_16A_ROW_COUNT="$(jq -r '[.artifacts[] | select(.source == ".claude/workflows/architect-deliberation.js")] | length' "$MANIFEST")"
assert_true "AC-59-16a: setup/manifest.json carries exactly one artifact row for architect-deliberation.js (got: $AC_59_16A_ROW_COUNT) (drift-immune: named-source state predicate, not a global count)" \
  "[ \"$AC_59_16A_ROW_COUNT\" -eq 1 ]"

REGISTRY_OUT="$(bash "$REGISTRY_RUNNER" 2>&1)"
PRE_EXISTING_FAILS="$(printf '%s\n' "$REGISTRY_OUT" | grep '^  FAIL: ' | awk '{print $2}' | grep -cv '^27-AC' || true)"
PRE_EXISTING_PASSES="$(printf '%s\n' "$REGISTRY_OUT" | grep '^  PASS: ' | awk '{print $2}' | grep -cv '^27-AC' || true)"
PRE_EXISTING_TOTAL="$(jq '[.invariants[] | select(.id | startswith("27-AC") | not)] | length' "$REGISTRY")"
assert_true "AC-59-16b: derived pre-existing (non-27-AC) registry PASS count == every pre-existing (non-27-AC) entry (got: $PRE_EXISTING_PASSES of $PRE_EXISTING_TOTAL, $PRE_EXISTING_FAILS failed)" \
  "[ \"$PRE_EXISTING_PASSES\" -eq \"$PRE_EXISTING_TOTAL\" ] && [ \"$PRE_EXISTING_FAILS\" -eq 0 ]"


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
# AC-59-19b (-total and -guarded) are retired by issue #103, with the lane they measured.
# =============================================================================
# Each was a SELF-SCOPED STRUCTURAL GREP over this file's own AC-59-11d /
# AC-59-21 delta block — counting its seven `-ge` comparisons, its seven
# precondition labels, and their interpolations. The leaf rule removed that
# block (each of the six re-run siblings carries its own `run:` step), so these
# assert a shape over source that is gone: they would count zero and red, or be
# rewritten to expect zero and assert nothing.

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
# AC-59-22a and AC-59-22b are retired by issue #103, with the lane they measured.
# =============================================================================
# Each was a SELF-SCOPED STRUCTURAL GREP over this file's own AC-59-11d /
# AC-59-21 delta block — counting its seven `-ge` comparisons, its seven
# precondition labels, and their interpolations. The leaf rule removed that
# block (each of the six re-run siblings carries its own `run:` step), so these
# assert a shape over source that is gone: they would count zero and red, or be
# rewritten to expect zero and assert nothing.

# =============================================================================
# Cycle 3's AC-59-25 … AC-59-35b lanes are retired by issue #103.
# =============================================================================
# Every one of them copied tests/issue-59-full-sweep-driver.sh into a throwaway
# fixture repo and ran it as a program. That driver is deleted: its function —
# enumerate every suite and execute the tree under an honest wall-clock budget —
# is `bash scripts/test/run-suites.sh --all`, which unlike the driver has a real
# execution path.
#
# The three properties these lanes asserted are re-homed, not dropped:
#   - unresolvable-base behaviour -> scripts/test/select-suites.sh's fail-loud
#     BLOCK contract, driven by its own --self-test BLOCK leg and by
#     tests/test-issue-103-central-runner.sh
#   - budget honesty -> run-suites.sh's per-suite `timeout <budget-secs>` and
#     TIMEOUT record, driven by the over-budget / under-budget stub pair in the
#     same suite
#   - sandbox containment -> the runner executes each suite in a subshell rooted
#     at --root and creates no worktree at all, so the class the containment
#     fences guarded is not representable rather than re-asserted
# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
