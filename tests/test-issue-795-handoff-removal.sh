#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: HANDOFF CI machine removal — Issue #795 (`subrepo-merged` retirement)
# =============================================================================
# Verification design: .autoflow/issue-795-verification-design.md (Reading B —
# ADR-0015 D3: physical REMOVAL, not conditionalization). Feature design:
# .autoflow/issue-795-feature-design.md. Reuses the assert_true/assert_false
# helper pattern from tests/test-issue-794-doc-assertions.sh /
# tests/test-issue-495-token-scope.sh — dependency-free bash+grep/awk.
#
# Subject under change: deletion of .github/workflows/handoff-sequence.yml
# (the `subrepo-merged` repository_dispatch status-check machinery), while
# preserving the `blocked-by-subrepo` operator label gate + pointer-reconcile
# procedure (S11b/#799 territory, untouched here).
#
# §0.2 (verification design) — every absence assertion below must RED
# pre-change (the machine still exists today) and GREEN post-change. A
# pre-change GREEN on an absence assertion is a vacuous/mis-scoped test, not
# a pass — see the RED expectation notes on each AC block.
#
# ACs covered (verification design §2, Reading B):
#   AC-DEL-WF        - handoff-sequence.yml deleted (RED pre-change)
#   AC-DEL-DISPATCH  - 'subrepo-merged' absent from autoflow-guide.md +
#                      external-review-sequencing.md ONLY (RED pre-change;
#                      git-workflow.md is explicitly OUT of this AC's scope
#                      — §1.4 freeze, see AC-KEEP-LABEL below)
#   AC-DEL-TOKEN     - SUBREPO_READ_TOKEN consumer gone; test-issue-495
#                      deleted with its subject (RED pre-change)
#   AC-KEEP-LABEL    - 'blocked-by-subrepo' + reconcile requirement preserved;
#                      create-host-pr.sh label logic (:47-50) byte-unchanged;
#                      git-workflow.md L120-157 stays diff-free vs merge-base
#                      (GREEN pre-change AND post-change — a pre-change RED
#                      here is a harness/scope bug, not a #795 gap)
#   AC-ORPHAN        - no dangling live reference to the removed machine
#                      outside the allow-list (RED pre-change)
#   AC-INVENTORY     - GATE:QUALITY FAIL follow-up: docs/host-service-
#                      decoupling-plan.md §10.2 test-inventory KEEP rows must
#                      not dangle (named file absent = stale row, no
#                      supersession annotation recorded); and no tests/ file
#                      (outside this verification suite's own negated-needle
#                      reference) may still cite the deleted
#                      test-issue-495-token-scope suite by name (RED
#                      pre-change: docs/host-service-decoupling-plan.md:447,
#                      451, 452 are unannotated KEEP rows naming files this
#                      cycle deleted, and
#                      tests/test-issue-788-host-purity-delta.sh:76 still
#                      cites test-issue-495-token-scope.sh as its helper-
#                      pattern source).
#
# NOT covered here (per verification design, GREEN-phase / out-of-suite):
#   AC-794-SPLIT (tests/test-issue-794-doc-assertions.sh per-token reversal —
#     lands in the SAME commit as the doc surgery, i.e. GREEN, not RED);
#   tests/issue-92/*.bats reversal (feature T1-T5, GREEN-phase);
#   tests/issue-92/manual-checklist.md cleanup (feature T8, GREEN-phase);
#   AC-VALID / AC-E2E (environment-dependent — see
#     tests/manual/issue-795-manual-scenarios.md).
#
# RED expectation (verification design §5): AC-DEL-WF, AC-DEL-DISPATCH,
# AC-DEL-TOKEN, AC-ORPHAN FAIL against the current (untouched) tree; only
# AC-KEEP-LABEL is expected GREEN pre-change (preservation arm — see notice
# above).
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

WORKFLOW="$PROJECT_ROOT/.github/workflows/handoff-sequence.yml"
AUTOFLOW_GUIDE="$PROJECT_ROOT/docs/autoflow-guide.md"
EXTERNAL_REVIEW="$PROJECT_ROOT/docs/external-review-sequencing.md"
GIT_WORKFLOW="$PROJECT_ROOT/docs/git-workflow.md"
SUBMODULE_RULES="$PROJECT_ROOT/docs/submodule-common-rules.md"
MAINTAINED_DOCS="$PROJECT_ROOT/docs/maintained-docs.md"
PR_TEMPLATE="$PROJECT_ROOT/.github/pull_request_template.md"
CREATE_HOST_PR="$PROJECT_ROOT/scripts/handoff/create-host-pr.sh"
TEST_ISSUE_495="$PROJECT_ROOT/tests/test-issue-495-token-scope.sh"

PASS=0; FAIL=0; TESTS=0

# ---------------------------------------------------------------------------
# Helpers (assert_true/assert_false pattern per tests/test-issue-794-doc-assertions.sh)
# ---------------------------------------------------------------------------

assert_true() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if eval "$condition"; then
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
  if eval "$condition"; then
    echo "  FAIL: $desc (forbidden condition held)"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

# =============================================================================
echo "=== AC-DEL-WF: handoff-sequence.yml deleted ==="
# RED expectation: FAIL today — file exists (verified 11216 bytes at
# authoring time). GREEN once the whole file is removed (feature C1).
assert_false \
  "AC-DEL-WF: .github/workflows/handoff-sequence.yml no longer exists" \
  "[ -f '$WORKFLOW' ]"

# =============================================================================
echo ""
echo "=== AC-DEL-DISPATCH: 'subrepo-merged' absent from autoflow-guide.md + external-review-sequencing.md ONLY ==="
# Scope bound (verification design §1.4/DQ-A): this AC's absence surface is
# EXACTLY {autoflow-guide.md, external-review-sequencing.md}. docs/git-workflow.md
# is explicitly excluded — its 'subrepo-merged' occurrences (:129,:157) sit
# inside the #794-frozen L120-157 reconcile block (S8 does not edit it; see
# AC-KEEP-LABEL's git-workflow-freeze arm below). This AC MUST NOT assert
# 'subrepo-merged' absence over git-workflow.md.
# RED expectation: FAIL today (both docs carry the token — verified
# autoflow-guide.md:529,583,585,587; external-review-sequencing.md multiple
# lines). GREEN once D1/D2 remove the machine narration.
assert_false \
  "AC-DEL-DISPATCH: docs/autoflow-guide.md has no 'subrepo-merged' token" \
  "grep -qF 'subrepo-merged' '$AUTOFLOW_GUIDE'"

assert_false \
  "AC-DEL-DISPATCH: docs/external-review-sequencing.md has no 'subrepo-merged' token" \
  "grep -qF 'subrepo-merged' '$EXTERNAL_REVIEW'"

# =============================================================================
echo ""
echo "=== AC-DEL-TOKEN: SUBREPO_READ_TOKEN consumer removed ==="
# RED expectation: FAIL today — the workflow's fork step is the sole consumer
# (verified handoff-sequence.yml:170,177); docs still name the token; the
# #495 suite (entirely scoped to the deleted workflow) still exists. GREEN
# once the workflow is deleted (subsumes the sole consumer), D2/D4 drop the
# token narration from docs, and test-issue-495-token-scope.sh is removed
# (feature T6 — its sole subject, the workflow, is gone; no orphaned
# coverage of a surviving surface, per verification design §2 coverage-loss
# note).
assert_false \
  "AC-DEL-TOKEN: no live SUBREPO_READ_TOKEN reference under .github/" \
  "git -C '$PROJECT_ROOT' grep -qF 'SUBREPO_READ_TOKEN' -- '.github'"

assert_false \
  "AC-DEL-TOKEN: no live SUBREPO_READ_TOKEN reference under scripts/" \
  "git -C '$PROJECT_ROOT' grep -qF 'SUBREPO_READ_TOKEN' -- 'scripts'"

assert_false \
  "AC-DEL-TOKEN: docs/external-review-sequencing.md drops SUBREPO_READ_TOKEN narration" \
  "grep -qF 'SUBREPO_READ_TOKEN' '$EXTERNAL_REVIEW'"

assert_false \
  "AC-DEL-TOKEN: docs/maintained-docs.md drops SUBREPO_READ_TOKEN narration" \
  "grep -qF 'SUBREPO_READ_TOKEN' '$MAINTAINED_DOCS'"

assert_false \
  "AC-DEL-TOKEN: tests/test-issue-495-token-scope.sh removed (subject deleted, feature T6)" \
  "[ -f '$TEST_ISSUE_495' ]"

# =============================================================================
echo ""
echo "=== AC-KEEP-LABEL: 'blocked-by-subrepo' + reconcile requirement preserved (regression bar) ==="
# This is the primary regression bar under Reading B (verification design §0.4).
# RED expectation: GREEN pre-change (these are preservation assertions on
# strings/lines present today) and must STAY green post-change. A pre-change
# RED here signals an over-tight assertion or a harness/scope bug — NOT a
# #795 gap (verification design §5, closing note).

assert_true \
  "AC-KEEP-LABEL: 'blocked-by-subrepo' preserved in docs/external-review-sequencing.md" \
  "grep -qF 'blocked-by-subrepo' '$EXTERNAL_REVIEW'"
assert_true \
  "AC-KEEP-LABEL: 'blocked-by-subrepo' preserved in docs/git-workflow.md" \
  "grep -qF 'blocked-by-subrepo' '$GIT_WORKFLOW'"
# NOTE (deviation flagged): the verification design's AC-KEEP-LABEL Claim
# lists docs/submodule-common-rules.md among the docs carrying the literal
# 'blocked-by-subrepo' string, but the live file (verified: grep -n
# 'blocked-by-subrepo' docs/submodule-common-rules.md -> no match) only
# names the 'subrepo-merged' pointer-check machine reference (:69), not the
# label token itself. Asserting the literal string here would be a
# pre-change RED that is a harness/scope bug per verification design §5
# ("If AC-KEEP-LABEL ... REDs on the untouched tree, stop — that is a
# harness/scope bug, not a #795 gap"). Narrowed to the reconcile-requirement
# ('TARGET') assertion below, which the file does carry.
assert_true \
  "AC-KEEP-LABEL: 'blocked-by-subrepo' preserved in docs/autoflow-guide.md" \
  "grep -qF 'blocked-by-subrepo' '$AUTOFLOW_GUIDE'"

# create-host-pr.sh label-apply logic (:47-50) is untouched by S8 — only the
# header comment (:10-12, dispatch narration) is surgery-scoped (feature C2).
assert_true \
  "AC-KEEP-LABEL: create-host-pr.sh applies blocked-by-review label" \
  "grep -qF -- '--label \"blocked-by-review\"' '$CREATE_HOST_PR'"
assert_true \
  "AC-KEEP-LABEL: create-host-pr.sh applies blocked-by-subrepo label by default" \
  "grep -qF -- '--label \"blocked-by-subrepo\"' '$CREATE_HOST_PR'"
assert_true \
  "AC-KEEP-LABEL: create-host-pr.sh --no-subrepo-dep guard unchanged" \
  "grep -qF 'NO_SUBREPO_DEP' '$CREATE_HOST_PR'"

# Reconcile requirement (pointer == TARGET) survives as operator prose, not
# deleted with the machine — verification design §2 AC-KEEP-LABEL Method.
assert_true \
  "AC-KEEP-LABEL: pointer==TARGET reconcile requirement present in docs/external-review-sequencing.md" \
  "grep -qF 'TARGET' '$EXTERNAL_REVIEW'"
assert_true \
  "AC-KEEP-LABEL: pointer==TARGET reconcile requirement present in docs/submodule-common-rules.md" \
  "grep -qF 'TARGET' '$SUBMODULE_RULES'"

# git-workflow-freeze arm (verification design §1.4/§3.2, feature D3
# ROUND-2): the #794 negative guard on git-workflow.md L120-157 (Merge
# Sequencing + Pointer reconciliation) must stay diff-free vs merge-base —
# S8 must not touch this range (its subrepo-merged/merge_commit_sha tokens
# are S11b/#799-deferred). Re-run this guard at VERIFY/INTEGRATE too
# (verification design §3.2).
BASE_REF="$(git -C "$PROJECT_ROOT" merge-base HEAD main 2>/dev/null || echo "")"
if [[ -z "$BASE_REF" ]]; then
  echo "  SKIP: git-workflow.md L120-157 no-diff guard — no merge-base with main available"
  TESTS=$((TESTS + 1))
else
  assert_true \
    "AC-KEEP-LABEL: git-workflow.md L120-157 (Merge Sequencing + Pointer reconciliation) has no diff hunk vs merge-base ($BASE_REF)" \
    "[ -z \"\$(git -C '$PROJECT_ROOT' diff -U0 '$BASE_REF'...HEAD -- '$GIT_WORKFLOW' | grep -E '^@@' | grep -E '\\+1(2[0-9]|[3-5][0-7]),')\" ]"
fi

# =============================================================================
echo ""
echo "=== AC-ORPHAN: no dangling reference to the removed machine outside the allow-list ==="
# Method (verification design §2 AC-ORPHAN): git grep -Fl over the host tree
# for each removed-machine token must return ONLY the allow-listed files;
# anything else is a dangling orphan -> RED. Excludes: the services/
# submodule (out of host scope, separate INTEGRATE boundary check) and the
# absence-test suites themselves (this file, tests/test-issue-794-doc-
# assertions.sh, tests/issue-92/*.bats — verification code whose token
# occurrence is a negated needle, not a live reference; verification design
# §2 AC-ORPHAN ROUND-4, "mandatory").
#
# GREEN disposition (issue #795, open RED item resolved):
#   - tests/manual/issue-495-manual-scenarios.md was the manual companion of
#     the DELETED #495 token-scope suite (its whole subject — the workflow,
#     the SUBREPO_READ_TOKEN provisioning, the subrepo-merged dispatch — is
#     gone). Consistent with feature T6 (delete the coverage whose sole
#     subject is the deleted machine) and T8's remove-principle (the file is
#     all machine-check dead procedure; its operator label-gate content now
#     lives in issue-795-manual-scenarios.md AC-E2E), it is DELETED. Its stale
#     exclusion entry is removed here (partition bookkeeping — the file no
#     longer exists).
#   - tests/manual/issue-795-manual-scenarios.md is THIS cycle's AC-E2E manual
#     deliverable; it names `subrepo-merged`/`handoff-sequence` only to describe
#     the machine's ABSENCE for the operator (e.g. "no subrepo-merged status
#     check appears"). Same class as the absence-test suites already excluded
#     below — verification documentation whose token occurrence is a
#     describe-absence reference, not a live reference to a live machine — so
#     it is EXCLUDED from the orphan sweep (not an orphan).
#   - tests/test-issue-848-doc-assertions.sh + tests/manual/issue-848-manual-
#     scenarios.md (#848 admission): the #848 verification surface names
#     `handoff-sequence`/`subrepo-merged` only as negated needles / describe-
#     absence scenario prose (its AC3 asserts the retirement stays correctly
#     recorded in git-workflow.md) — the same class as the absence-test
#     suites and issue-795-manual-scenarios.md already excluded here, not a
#     live reference to a live machine.
EXCLUDE_PATHSPEC=(':!services' ':!.autoflow' \
  ':!tests/test-issue-795-handoff-removal.sh' \
  ':!tests/test-issue-794-doc-assertions.sh' \
  ':!tests/issue-92/*.bats' \
  ':!tests/manual/issue-795-manual-scenarios.md' \
  ':!tests/test-issue-848-doc-assertions.sh' \
  ':!tests/manual/issue-848-manual-scenarios.md')

# is_allowed <file> <allow-list...>
is_allowed() {
  local f="$1"; shift
  local a
  for a in "$@"; do
    [[ "$f" == "$a" ]] && return 0
  done
  return 1
}

orphan_check() {
  local desc="$1" token="$2"; shift 2
  local allow=("$@")
  local files orphans=()
  files="$(git -C "$PROJECT_ROOT" grep -Fl "$token" -- "${EXCLUDE_PATHSPEC[@]}" 2>/dev/null || true)"
  local f
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if ! is_allowed "$f" "${allow[@]}"; then
      orphans+=("$f")
    fi
  done <<< "$files"
  TESTS=$((TESTS + 1))
  if [[ ${#orphans[@]} -eq 0 ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (dangling: ${orphans[*]})"
    FAIL=$((FAIL + 1))
  fi
}

# Allow-lists per token (deliberately-kept historical/frozen references —
# verification design §2 AC-ORPHAN, ROUND-3/4/5/6 partition).
ALLOW_HANDOFF_SEQ=(
  "docs/adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md"
  "docs/git-workflow.md"
  "docs/host-service-decoupling-plan.md"
  "docs/improvement-backlog.md"
)
ALLOW_SUBREPO_MERGED=(
  "docs/adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md"
  "docs/adr/README.md"
  "docs/git-workflow.md"
  "docs/host-service-decoupling-plan.md"
  "docs/improvement-backlog.md"
  # #951 capture-before-delete baseline (tests/fixtures/doc-invariants-
  # baseline.txt, ledger E5): a captured VERBATIM stdout snapshot of the
  # retired tests/test-issue-794-doc-assertions.sh's own assertion
  # descriptions (e.g. "AC5d-invert: 'subrepo-merged' status-check machine
  # removed..."), taken before that suite's deletion. Same class as the
  # already-excluded absence-test suites and issue-795-manual-scenarios.md
  # above: a describe-absence/historical-record occurrence of the retired
  # machine's name, not a live reference to a live machine.
  "tests/fixtures/doc-invariants-baseline.txt"
  # #951 GREEN commit (5fa1c9e): the shipped permanent registry
  # (tests/fixtures/doc-invariants.json) migrates 794's own preservation/
  # coherence entries verbatim, including three literal `"literal":
  # "subrepo-merged"` present/absent checks (794-AC2-guide-subrepo-merged-
  # absent, 794-AC2-ext-subrepo-merged-absent, 794-AC2-git-subrepo-merged).
  # Same class as the baseline.txt entry above: the token occurs as
  # migrated-invariant DATA proving the machine's continued absence, not a
  # live reference to a live machine.
  "tests/fixtures/doc-invariants.json"
)
ALLOW_TOKEN=(
  "docs/adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md"
  "docs/host-service-decoupling-plan.md"
)

orphan_check \
  "AC-ORPHAN: 'handoff-sequence' has no dangling reference outside the allow-list" \
  "handoff-sequence" "${ALLOW_HANDOFF_SEQ[@]}"

orphan_check \
  "AC-ORPHAN: 'subrepo-merged' has no dangling reference outside the allow-list" \
  "subrepo-merged" "${ALLOW_SUBREPO_MERGED[@]}"

orphan_check \
  "AC-ORPHAN: 'SUBREPO_READ_TOKEN' has no dangling reference outside the allow-list" \
  "SUBREPO_READ_TOKEN" "${ALLOW_TOKEN[@]}"

# =============================================================================
echo ""
echo "=== AC-INVENTORY: host-service-decoupling-plan.md §10.2 test-inventory rows must not dangle ==="
# GATE:QUALITY FAIL finding (issue #795, GATE:QUALITY cycle 1): AC-ORPHAN's
# allow-list names docs/host-service-decoupling-plan.md wholesale, which
# masked row-level staleness WITHIN that same doc — three §10.2 KEEP rows
# (test-issue-495-token-scope.sh :447, test-handoff-sequence-workflow.bats
# :451, test-handoff-sequence-verification.bats :452) name files this cycle
# deletes, with no supersession/retire annotation on the row (asymmetric with
# §10.1's handoff-sequence.yml row, which DID get a
# "SUPERSEDED: RETIRED (ADR-0015 D3 / #795)" annotation this cycle). These
# assertions check the GENERAL property — every unannotated §10.2 KEEP row's
# path must exist — not just the three named lines, so any future row that
# goes stale the same way is caught too.
#
# RED expectation: FAIL today. The three rows above are unannotated KEEP with
# an absent file (verified: the files do not exist in the working tree —
# `ls tests/test-issue-495-token-scope.sh tests/issue-92/test-handoff-
# sequence-{workflow,verification}.bats` -> "No such file or directory" for
# all three), and tests/test-issue-788-host-purity-delta.sh:76 still names
# the deleted suite in its helper-pattern-source comment.

DECOUPLING_PLAN="$PROJECT_ROOT/docs/host-service-decoupling-plan.md"

inventory_keep_check() {
  local desc="$1"
  local section missing=()
  # Isolate the §10.2 table body only (between its heading and the next
  # prose section) so this check never wanders into §10.1/§10.3's own
  # (differently-shaped) inventory tables.
  section="$(awk 'BEGIN{f=0} f && /^주요 발견:/{exit} /^### 10\.2/{f=1} f{print}' "$DECOUPLING_PLAN")"
  while IFS= read -r line; do
    [[ "$line" =~ ^\|[[:space:]]*tests/ ]] || continue
    local path verdict
    path="$(awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2}' <<< "$line")"
    verdict="$(awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$3); print $3}' <<< "$line")"
    # Only exact-"KEEP" rows are in scope: an annotated/superseded row (e.g.
    # "~~KEEP~~ -> SUPERSEDED ...") no longer reads as literal "KEEP" and is
    # correctly out of scope for this dangling-reference guard.
    [[ "$verdict" == "KEEP" ]] || continue
    # Skip glob/group rows (e.g. "scripts/test/check-seed-*.sh (11개)") —
    # this AC checks concrete single-file rows, not pattern summaries.
    case "$path" in
      *'*'*|*'{'*|*'('*) continue ;;
    esac
    if [[ ! -e "$PROJECT_ROOT/$path" ]]; then
      missing+=("$path")
    fi
  done <<< "$section"
  TESTS=$((TESTS + 1))
  if [[ ${#missing[@]} -eq 0 ]]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (dangling KEEP row(s), file absent: ${missing[*]})"
    FAIL=$((FAIL + 1))
  fi
}

inventory_keep_check \
  "AC-INVENTORY: every unannotated §10.2 KEEP row's tests/ path exists in the working tree"

# Part (b): no file under tests/ still names the deleted suite by its
# filename stem — comment, path variable, or otherwise. This suite's own
# file is excluded (a negated-needle reference identical in kind to the
# AC-ORPHAN exclusions above: it names the deleted file only to assert its
# absence, not as a live reference to a live file).
assert_false \
  "AC-INVENTORY: no tests/ file (outside this suite) still references 'test-issue-495-token-scope'" \
  "git -C '$PROJECT_ROOT' grep -Fl 'test-issue-495-token-scope' -- 'tests' ':!tests/test-issue-795-handoff-removal.sh' 2>/dev/null | grep -q ."

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
