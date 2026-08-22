#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/workflows/architect-deliberation.js .claude/workflows/verify-cause-branch.js .github/workflows/e2e-dummy-target.yml docs/doc-invariant-registry.md setup/manifest.json test/workflows/run.mjs tests/fixtures/doc-invariants.json tests/run-doc-invariants.sh
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: ARCHITECT sequential rounds + citation partitioning — Issue #62 (cycle-scoped)
# (the original carry-compaction mechanism this header once described —
# compactCounter/openCounters — was retired by issue #67's issue-register
# redesign; this suite's own AC-62-31/AC-59-8d/carry-anchor rows track that
# retirement, so the header is updated to match rather than describe a
# mechanism no longer in the shipped script.)
# =============================================================================
# Cycle-scoped structural/count/execution guards per the verification design
# (.autoflow/issue-62-verification-design.md §1/§5 RED plan). Behavioral
# assertions on the composed prompts live in test/workflows/run.mjs (lane A);
# this suite carries the S-lane (structural grep / suite-invocation / registry
# / manifest / CI-registration) criteria that a mock-runtime test cannot
# express: AC-62-5, 18, 20-26, 29-35.
#
# Retired (#107): this suite once carried a branch-scoped tier gated on
# dev/*-issue-62 — AC-62-23 (the harness ok-count pin, whose literal 58 had
# gone stale against the single-sourced tests/lib/harness-pins.sh and whose
# measurement runs unconditionally in
# tests/test-issue-27-composition-oracle.sh), AC-62-35 (a
# `.autoflow/issue-62-runtime-launch.json` record, gitignored and so a
# VALIDATE-time obligation of that cycle alone), and the gate around the D10
# arm-shape controls. The first two were deleted; the controls were UNGATED.
# See docs/doc-invariant-registry.md §12 and §12.1.
#
# AC-62-36 — retired in #121, with its three controls, because its SUBJECT was.
# That subject was the `.claude/workflows/**` arm that both scope guards
# carried, and #121 retired that arm from both files as an un-gated DELTA over
# a merged cycle's own diff. A shape guard over an arm that no longer exists is
# vacuous, not lost; what survives is the content predicate in
# scripts/test/check-manifest-regen-clean.sh's FIXED POINT leg. The two mutators
# and the arm-window extractor left with the arms; the worktree driver stays,
# because another suite asserts its retention by name. §16 supersedes §12.1's
# two AC-62-36 disposition rows.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKFLOW_JS="$PROJECT_ROOT/.claude/workflows/architect-deliberation.js"
VERIFY_JS="$PROJECT_ROOT/.claude/workflows/verify-cause-branch.js"
RUN_MJS="$PROJECT_ROOT/test/workflows/run.mjs"
MANIFEST="$PROJECT_ROOT/setup/manifest.json"
CI_WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"
REGISTRY="$PROJECT_ROOT/tests/fixtures/doc-invariants.json"

# B11: verify-cause-branch.js sha256 must stay unchanged (out of this cycle's scope).
# B11 update (issue #97): #97 added the ledger entry-ID allocation prompt to
# verify-cause-branch.js's cause-branch script (the same file this pin covers),
# so this cycle's own change legitimately moves the sha256 rather than
# violating the negative-control fence. Bumped in the same commit as the
# underlying change per this suite's own precedent (d333532 #69, e96d4bd #75,
# 7dc3927 #67).
B11_SHA="72a7be6309fe7e74ec48c99df27478a6f94de1f6db5741972e14728b18927322"

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

# Mirrors tests/test-issue-59-adoption-evidence-discipline.sh:232-249's
# suite_result_at_ref() shape (E33 lesson: real re-run in an isolated detached
# worktree, never a re-implemented copy of the guard's own logic — C3). This
# variant additionally accepts a mutator callback applied to the worktree
# BEFORE the guard runs, so a negative control can drive the REAL guard file
# against a REAL tampered/deleted on-disk state (O9, non-mock).
# Always cleans up via `git worktree remove --force`, even on a guard failure,
# so a failed lane cannot leak a worktree into `git worktree list`.
#
# RETAINED against the orphan rule (#121): this cycle deleted every call site,
# but tests/test-cycle-arm-residue.sh asserts this definition's retention BY
# NAME against docs/doc-invariant-registry.md §12.1's kept row, so it is a
# symbol another file requires rather than an orphan.
guard_result_at_ref_mutated() {
  local ref="$1" suite_name="$2" mutator="$3"
  local wt out
  wt="$(mktemp -d)"
  if ! git -C "$PROJECT_ROOT" worktree add -q --detach "$wt" "$ref" >/dev/null 2>&1; then
    rm -rf "$wt"
    printf '%s' ""
    return
  fi
  if [[ -n "$mutator" ]]; then
    "$mutator" "$wt" >/dev/null 2>&1 || true
  fi
  if [[ -f "$wt/tests/$suite_name" ]]; then
    out="$(cd "$wt" && bash "tests/$suite_name" 2>&1)"
  else
    out=""
  fi
  git -C "$PROJECT_ROOT" worktree remove --force "$wt" >/dev/null 2>&1
  printf '%s' "$out"
}

# =============================================================================
echo "=== AC-62-5 (RED discriminator) — parallel( appears exactly once, on the Draft site ==="

PARALLEL_COUNT="$(grep -c 'parallel(' "$WORKFLOW_JS" || true)"
assert_true "AC-62-5a: parallel( occurs exactly once in architect-deliberation.js (got: $PARALLEL_COUNT)" \
  "[ \"$PARALLEL_COUNT\" -eq 1 ]"

PARALLEL_LINE="$(grep -n 'parallel(' "$WORKFLOW_JS" | head -1)"
assert_true "AC-62-5b: the single parallel( site is the Draft-round 'const [devDraft, testDraft]' line" \
  "printf '%s' '$PARALLEL_LINE' | grep -q 'const \[devDraft, testDraft\]'"

# =============================================================================
echo ""
echo "=== AC-62-18 (fence, load-bearing) — permanent registry rows survive, none deleted ==="
# The re-run half (AC-62-18a: no pre-existing registry row FAILs) retired in
# issue #122 — carried by the bare `run: bash tests/run-doc-invariants.sh` step
# in contract-suites.yml. What survives is a state predicate over the registry
# FILE, which re-executes nothing.

CUR_ROW_COUNT="$(jq '.invariants | length' "$REGISTRY")"
COMMITTED_ROW_COUNT="$(cd "$PROJECT_ROOT" && git show HEAD:tests/fixtures/doc-invariants.json 2>/dev/null | jq '.invariants | length' 2>/dev/null || echo 0)"
assert_true "AC-62-18b: registry row count is non-decreasing vs. the last commit (committed: $COMMITTED_ROW_COUNT, working: $CUR_ROW_COUNT)" \
  "[ \"$CUR_ROW_COUNT\" -ge \"$COMMITTED_ROW_COUNT\" ]"

# =============================================================================
echo ""
echo "=== AC-62-21 (fence) — negative-control pins: verify-cause-branch.js sha + manifest artifact count ==="

CUR_VERIFY_SHA="$(shasum -a 256 "$VERIFY_JS" | awk '{print $1}')"
assert_true "AC-62-21a: verify-cause-branch.js sha256 unchanged (B11 $B11_SHA) (got: $CUR_VERIFY_SHA)" \
  "[ \"$CUR_VERIFY_SHA\" = \"$B11_SHA\" ]"

# AC-62-21b was a global artifact-count fence (== 47) — the retired
# ADR-0016 AC-R3-c count-guard class (docs/doc-invariant-registry.md:113),
# same defect the registry's own row for this class documents at
# docs/doc-invariant-registry.md:114 (test-issue-27-composition-oracle.sh
# AC-27-21a, reddened by issue #51's ADR-0017 manifest row, 47 -> 48).
# Converted to the drift-immune shape used there: a state predicate over the
# three named sources this suite names below, not a global count.
MANIFEST_ARTIFACT_COUNT="$(jq '.artifacts | length' "$MANIFEST")"
echo "  (info) AC-62-21b: setup/manifest.json artifact count is currently $MANIFEST_ARTIFACT_COUNT (informational — not asserted; see conversion note above)"

AC_62_21B_NAMED_SOURCES=(
  ".claude/workflows/architect-deliberation.js"
  "docs/teammate-contracts.md"
  "docs/autoflow-guide.md"
)
AC_62_21B_BAD=0
for src in "${AC_62_21B_NAMED_SOURCES[@]}"; do
  cnt="$(jq -r --arg s "$src" '[.artifacts[] | select(.source == $s)] | length' "$MANIFEST")"
  if [ "$cnt" -ne 1 ]; then
    AC_62_21B_BAD=$((AC_62_21B_BAD + 1))
    echo "  (info) AC-62-21b: manifest artifact row count for '$src' == $cnt (expected 1)"
  fi
done
assert_true "AC-62-21b: setup/manifest.json carries exactly one artifact row for each of this suite's three pinned sources (drift-immune: named-source state predicate, not a global count)" \
  "[ '$AC_62_21B_BAD' -eq 0 ]"


# =============================================================================
# AC-62-22 is retired by issue #103's leaf rule.
# =============================================================================
# It re-ran tests/test-issue-955-subagent-background-ban.sh as a fence. That
# suite carries its own `run:` step, so the fence is executed once per pass
# either way.

# =============================================================================
# AC-62-24 is retired by issue #103's leaf rule.
# =============================================================================
# The fence re-ran three sibling suites (56, 59, 27) to confirm the ok-count pin
# had been bumped in every home. Single-sourcing the pin into
# tests/lib/harness-pins.sh leaves one home, so there is no cross-home bump left
# to fence — and each of the three carries its own `run:` step, so an unrelated
# regression in any of them reds CI under its own name.

# =============================================================================
# AC-62-25a / AC-62-25b are migrated to the registry by issue #120.
# =============================================================================
# Both read the Facilitator > ARCHITECT block of docs/teammate-contracts.md,
# whose `**ARCHITECT**` opening and `**VERIFY**` terminator are column-1 fixed
# prefixes — the registry's `section_kind: "block"` anchor form. Migrated as
# `120-62-contracts-architect-sequential` and
# `120-62-contracts-architect-citation-mode` under the case-explicit-rewrite
# rule (both arms matched case-insensitively; the entries spell the case the
# document actually uses). Disposition recorded: docs/doc-invariant-registry.md
# §17.

# =============================================================================
echo ""
echo "=== AC-62-26 (RED discriminator, DCR-8) — new suite registered in e2e-dummy-target.yml (both paths: blocks + a run: step) ==="

SUITE_NAME="tests/test-issue-62-sequential-rounds.sh"
if [[ -f "$CI_WORKFLOW" ]]; then
  PR_SECTION="$(awk '/^  push:/{exit} {print}' "$CI_WORKFLOW")"
  PUSH_SECTION="$(awk 'f && /^[a-zA-Z]/{exit} f{print} /^  push:/{f=1}' "$CI_WORKFLOW")"

  PR_PATHS_PRECEDES="$(printf '%s\n' "$PR_SECTION" | awk -v pat="$SUITE_NAME" '/^ *paths:/{p=1} index($0,pat){print (p==1)?"yes":"no"; f=1; exit} END{if(!f) print "no"}')"
  assert_true "AC-62-26a-pr: $SUITE_NAME appears in the pull_request 'paths:' trigger block" \
    "[ \"$PR_PATHS_PRECEDES\" = yes ]"

  PUSH_PATHS_PRECEDES="$(printf '%s\n' "$PUSH_SECTION" | awk -v pat="$SUITE_NAME" '/^ *paths:/{p=1} index($0,pat){print (p==1)?"yes":"no"; f=1; exit} END{if(!f) print "no"}')"
  assert_true "AC-62-26a-push: $SUITE_NAME appears in the push 'paths:' trigger block" \
    "[ \"$PUSH_PATHS_PRECEDES\" = yes ]"

  assert_true "AC-62-26b: $SUITE_NAME appears in a 'run:' step" \
    "ctx=\$(grep -A2 -F '$SUITE_NAME' '$CI_WORKFLOW'); printf '%s\n' \"\$ctx\" | grep -qF 'run: bash $SUITE_NAME'"
else
  assert_true "AC-62-26a-pr: $CI_WORKFLOW exists" "false"
  echo "  BLOCK: AC-62-26a-push/AC-62-26b unmeasurable (workflow file missing) — counted FAIL, never skipped"
  TESTS=$((TESTS + 2)); FAIL=$((FAIL + 2))
fi

# =============================================================================
echo ""
echo "=== AC-62-29 (RED discriminator, DCR-9) — no executable dynamic import() remains, and node --check passes ==="

NONCOMMENT_IMPORT_COUNT=0
for f in "$PROJECT_ROOT"/.claude/workflows/*.js; do
  c="$(grep -v '^[[:space:]]*//' "$f" | grep -cE 'import[[:space:]]*\(' || true)"
  NONCOMMENT_IMPORT_COUNT=$((NONCOMMENT_IMPORT_COUNT + c))
done
assert_true "AC-62-29a: zero non-comment-line import( occurrences across .claude/workflows/*.js (got: $NONCOMMENT_IMPORT_COUNT)" \
  "[ \"$NONCOMMENT_IMPORT_COUNT\" -eq 0 ]"

NODE_CHECK_OK=true
for f in "$PROJECT_ROOT"/.claude/workflows/*.js; do
  node --check "$f" >/dev/null 2>&1 || NODE_CHECK_OK=false
done
assert_true "AC-62-29b: node --check exits 0 for every .claude/workflows/*.js" "[ \"$NODE_CHECK_OK\" = true ]"

# =============================================================================
echo ""
echo "=== AC-62-30 (RED discriminator, DCR-9) — retired artifact-existence path leaves no dangling reference ==="

DANGLING_CONST="$(grep -c 'REASON_DRAFT_ARTIFACT_MISSING' "$WORKFLOW_JS" || true)"
assert_true "AC-62-30a: REASON_DRAFT_ARTIFACT_MISSING absent from architect-deliberation.js (got: $DANGLING_CONST)" \
  "[ \"$DANGLING_CONST\" -eq 0 ]"

DANGLING_STRING="$(grep -c 'draft artifact missing' "$WORKFLOW_JS" || true)"
assert_true "AC-62-30b: the literal 'draft artifact missing' absent from architect-deliberation.js (got: $DANGLING_STRING)" \
  "[ \"$DANGLING_STRING\" -eq 0 ]"

POSITIVE_MATCH_COUNT="$(grep -c 'draft artifact missing' "$RUN_MJS" || true)"
NEGATED_MATCH_COUNT="$(grep -c '!String(result.escalation' "$RUN_MJS" || true)"
assert_true "AC-62-30c: every 'draft artifact missing' occurrence in run.mjs sits inside a negated assertion (positive: $POSITIVE_MATCH_COUNT, negated-assertion sites: $NEGATED_MATCH_COUNT)" \
  "[ \"$POSITIVE_MATCH_COUNT\" -eq \"$NEGATED_MATCH_COUNT\" ]"


# =============================================================================
# AC-62-31 (a / a-label / a-stale / b / c / d) is retired by issue #103.
# =============================================================================
# The block asserted this cycle's BUMP DISCIPLINE — that the harness change
# bumped both foreign ok-count pin homes in the same commit, and that no stale
# literal from the preceding generation survived. Single-sourcing the pin into
# tests/lib/harness-pins.sh leaves no foreign home and no synchronised bump, so
# the subject is gone; a staleness assertion over a literal that no longer
# exists anywhere is vacuously true, which is the vacuous-PASS class this tree
# removes rather than keeps. AC-62-31d's sibling invocation is separately
# disposed by the leaf rule.
#
# The surviving property — one authoring home — is carried by
# scripts/test/check-suite-manifest.sh's single-authorship arm.

# =============================================================================
# AC-62-32 (a / a2 / b / c) and AC-62-34 are migrated to the registry by #120.
# =============================================================================
# Four of the five were `grep -c <literal> <file> -eq 0` over a whole file —
# `absent` + `match: "fixed"` in registry form, the shape the self-test's
# injection mutator credits. AC-62-32(b) split: its positive half (the
# ARCHITECT section states the both-artifacts-exist-and-non-empty
# precondition) migrated; its "exactly once" count fence dropped, since a
# count-shaped predicate can never be a permanent registry entry
# (docs/doc-invariant-registry.md §1-2, the §6 `844 AC4-h` precedent).
# Carriers: `120-62-contracts-no-draft-artifact-missing`,
# `120-62-contracts-no-antecedent-clause`,
# `120-62-guide-architect-artifacts-precondition`,
# `120-62-contracts-no-fs-smoke`, `120-62-contracts-no-missing-artifact`.
# Disposition recorded: docs/doc-invariant-registry.md §17.

# =============================================================================
# AC-62-37 is retired by issue #103's leaf rule.
# =============================================================================
# It re-ran four sibling suites (798, 799, 59, 964) to confirm the D10 amendment
# had regressed none of them. Each carries its own `run:` step, so a regression
# in any of them reds CI under its own name, once per pass rather than twice.

# =============================================================================
echo ""
echo "=== AC-62-38 (fence, no run.mjs case) — the D10 replacement's pipeline shape trips neither frozen #964 hazard regex ==="
# Frozen literals, quoted verbatim from tests/test-issue-964-sigpipe-safe-pipes.sh:95
# (GUARD_REGEX) and :103 (EXTRACTOR_GUARD_REGEX) — never re-derived or reworded
# here, since a copy that drifts from the frozen source would silently stop
# discriminating the hazard class #964 exists to catch.
GUARD_REGEX_964='grep -[ABC] ?[0-9]+ [^)]*\| grep -q'
EXTRACTOR_GUARD_REGEX_964='(^|[[:space:]"'"'"'])[a-zA-Z_][a-zA-Z0-9_]* \| grep -[qm]'

M798_G="$(grep -cE "$GUARD_REGEX_964" "$PROJECT_ROOT/tests/test-issue-798-topology-flip.sh" || true)"
M798_E="$(grep -cE "$EXTRACTOR_GUARD_REGEX_964" "$PROJECT_ROOT/tests/test-issue-798-topology-flip.sh" || true)"
M799_G="$(grep -cE "$GUARD_REGEX_964" "$PROJECT_ROOT/tests/test-issue-799-inert-cleanup.sh" || true)"
M799_E="$(grep -cE "$EXTRACTOR_GUARD_REGEX_964" "$PROJECT_ROOT/tests/test-issue-799-inert-cleanup.sh" || true)"
assert_true "AC-62-38: neither #964 frozen hazard regex (GUARD_REGEX / EXTRACTOR_GUARD_REGEX, tests/test-issue-964-sigpipe-safe-pipes.sh:95,:103) matches tests/test-issue-798-topology-flip.sh or tests/test-issue-799-inert-cleanup.sh (798: GUARD=$M798_G/EXTRACTOR=$M798_E, 799: GUARD=$M799_G/EXTRACTOR=$M799_E)" \
  "[ \"$M798_G\" -eq 0 ] && [ \"$M798_E\" -eq 0 ] && [ \"$M799_G\" -eq 0 ] && [ \"$M799_E\" -eq 0 ]"

# =============================================================================
echo ""
echo "=== AC-62-39 (fence) — no derived-artifact regeneration owed for the two guards' own change ==="

MANIFEST_TESTS_ROWS="$(jq -r '.artifacts[].source' "$MANIFEST" | grep -c '^tests/' || true)"
assert_true "AC-62-39: setup/manifest.json carries zero 'tests/…' source rows, so editing a test file owes no manifest regeneration (got: $MANIFEST_TESTS_ROWS)" \
  "[ \"$MANIFEST_TESTS_ROWS\" -eq 0 ]"

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
