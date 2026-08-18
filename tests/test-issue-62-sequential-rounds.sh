#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/workflows/architect-deliberation.js .claude/workflows/verify-cause-branch.js .github/workflows/e2e-dummy-target.yml docs/autoflow-guide.md docs/doc-invariant-registry.md docs/teammate-contracts.md setup/manifest.json test/workflows/run.mjs tests/fixtures/doc-invariants.json tests/run-doc-invariants.sh
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
# VALIDATE-time obligation of that cycle alone), and the gate around
# AC-62-36(iii)/(iv). The first two were deleted; the AC-62-36 controls were
# UNGATED — (iv) was already branch-independent, and (iii) became so once its
# mutator was made hermetic (see stale_workflow_manifest_row below). See
# docs/doc-invariant-registry.md §12 and §12.1.
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
REGISTRY_RUNNER="$PROJECT_ROOT/tests/run-doc-invariants.sh"
TEAMMATE_CONTRACTS="$PROJECT_ROOT/docs/teammate-contracts.md"
AUTOFLOW_GUIDE="$PROJECT_ROOT/docs/autoflow-guide.md"

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


# D10 ARM WINDOW extractor (verification design §7.2a): the inclusive line
# range from the FIRST line matching the workflows_{admitted,touched,offwindow}
# accumulator seed to the FIRST SUBSEQUENT assert_true "AC(9|6-scope): line.
# Resolves both pre-D10 (798:249-266, 799:841-868 today) and post-D10 (the
# manifest-pin replacement block) — if either anchor is absent the extraction
# is empty, which the structural counts below turn into a FAIL, never a
# vacuous pass.
extract_arm_window() {
  awk '
    !started && /^[[:space:]]*workflows_(admitted|touched|offwindow)_ac[0-9]/ { started=1 }
    started { print }
    started && /^[[:space:]]*assert_true "AC(9|6-scope):/ { exit }
  ' "$1"
}

# Mirrors tests/test-issue-59-adoption-evidence-discipline.sh:232-249's
# suite_result_at_ref() shape (E33 lesson: real re-run in an isolated detached
# worktree, never a re-implemented copy of the guard's own logic — C3). This
# variant additionally accepts a mutator callback applied to the worktree
# BEFORE the guard runs, so AC-62-36(iii)/(iv)'s negative controls drive the
# REAL guard file against a REAL tampered/deleted on-disk state (O9, non-mock).
# Always cleans up via `git worktree remove --force`, even on a guard failure,
# so a failed lane cannot leak a worktree into `git worktree list`.
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

# AC-62-36(iii) mutator: commit a content edit to the workflow file inside the
# worktree and leave its setup/manifest.json row untouched — the stale-row
# condition (wf_sha != man_sha) the guard's arm claims to detect, produced by
# the mutator itself rather than borrowed from the host branch's diff.
#
# The committed edit is what makes this control HERMETIC (#107). The guard's
# .claude/workflows/** arm iterates over the worktree's own BASE_REF...HEAD
# diff and passes when that diff touches no such path, so a mutator that only
# rewrites an uncommitted setup/manifest.json — the earlier sha-tamper shape —
# produced a FAIL only when the HOST branch happened to commit a
# .claude/workflows/** change. The branch gate around this arm was supplying
# that premise; committing the workflow-file edit here supplies it locally and
# is simultaneously the stale row being asserted.
#
# The commit identity is process-local via `git -c` for the reason
# delete_workflow_and_manifest_row documents below.
stale_workflow_manifest_row() {
  local wt="$1"
  local wf_path=".claude/workflows/architect-deliberation.js"
  [[ -f "$wt/$wf_path" && -f "$wt/setup/manifest.json" ]] || return 1
  printf '\n// AC-62-36(iii) fixture: content edit, manifest row left stale\n' >> "$wt/$wf_path"
  git -C "$wt" add -- "$wf_path" >/dev/null 2>&1
  git -c user.email="test-issue-62@example.com" -c user.name="test-issue-62" \
    -C "$wt" commit -q -m "AC-62-36(iii) fixture: edit workflow file, leave manifest row stale" >/dev/null 2>&1
}

# AC-62-36(iv) mutator: delete the workflow file AND its manifest row inside
# the worktree, then commit — the empty-vs-empty vacuity class (C2) the D10
# predicate must not silently admit. The commit's identity is scoped to THIS
# invocation only via `git -c user.email=... -c user.name=...` (GATE:QUALITY
# fix, regression 1/3): `git -C "$wt" config user.email/user.name` writes to
# the SHARED .git/config of a linked worktree (extensions.worktreeConfig is
# unset in this repo), which would permanently rewrite the host repository's
# identity — not scoped to the worktree the way it would be in a standalone
# git-init'd fixture repo (tests/test-issue-979-review-backend.sh:73 is safe
# for exactly that reason: that fixture is its own repo, not a linked
# worktree of the host). `-c` config overrides are process-local and never
# touch any on-disk config file.
delete_workflow_and_manifest_row() {
  local wt="$1"
  local wf_path=".claude/workflows/architect-deliberation.js"
  local manifest="$wt/setup/manifest.json"
  [[ -f "$wt/$wf_path" && -f "$manifest" ]] || return 1
  jq 'del(.artifacts[] | select(.source==".claude/workflows/architect-deliberation.js"))' \
    "$manifest" > "$manifest.tmp" && mv "$manifest.tmp" "$manifest"
  git -C "$wt" rm -q -- "$wf_path" >/dev/null 2>&1
  git -C "$wt" add -A -- "$manifest" >/dev/null 2>&1
  git -c user.email="test-issue-62@example.com" -c user.name="test-issue-62" \
    -C "$wt" commit -q -m "AC-62-36(iv) fixture: delete workflow file + manifest row" >/dev/null 2>&1
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

REGISTRY_OUT="$(bash "$REGISTRY_RUNNER" 2>&1)"
# Scoped like AC-59-16b: this cycle's OWN new rows (62-AC*) are expected to
# stay RED until GREEN lands the mechanism they pin — that is a separate,
# already-covered discriminator (the registry rows above / this suite's own
# AC-62-15/16/28 counterparts). AC-62-18 is about every OTHER (pre-existing)
# permanent invariant not regressing.
PRE_EXISTING_FAILS="$(printf '%s\n' "$REGISTRY_OUT" | grep '^  FAIL: ' | awk '{print $2}' | grep -cv '^62-AC' || true)"
assert_true "AC-62-18a: every pre-existing (non-62-AC) registry row still passes (got: $PRE_EXISTING_FAILS failed)" \
  "[ \"$PRE_EXISTING_FAILS\" -eq 0 ]"

CUR_ROW_COUNT="$(jq '.invariants | length' "$REGISTRY")"
COMMITTED_ROW_COUNT="$(cd "$PROJECT_ROOT" && git show HEAD:tests/fixtures/doc-invariants.json 2>/dev/null | jq '.invariants | length' 2>/dev/null || echo 0)"
assert_true "AC-62-18b: registry row count is non-decreasing vs. the last commit (committed: $COMMITTED_ROW_COUNT, working: $CUR_ROW_COUNT)" \
  "[ \"$CUR_ROW_COUNT\" -ge \"$COMMITTED_ROW_COUNT\" ]"

# =============================================================================
echo ""
echo "=== AC-62-20 (fence — will FAIL mid-GREEN until manifest is regenerated, gate at GREEN close) — manifest hash freshness (widened to 3 sources) ==="

for SRC in ".claude/workflows/architect-deliberation.js" "docs/teammate-contracts.md" "docs/autoflow-guide.md"; do
  MANIFEST_SHA="$(jq -r --arg s "$SRC" '.artifacts[] | select(.source==$s) | .sha256' "$MANIFEST")"
  CUR_SHA="$(shasum -a 256 "$PROJECT_ROOT/$SRC" | awk '{print $1}')"
  assert_true "AC-62-20 ($SRC): manifest row sha256 == live file sha256 (manifest: $MANIFEST_SHA, current: $CUR_SHA)" \
    "[ \"$MANIFEST_SHA\" = \"$CUR_SHA\" ]"
done

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
# three named sources this suite actually pins manifest-hash freshness for
# just above (AC-62-20's loop), not a global count.
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
echo ""
echo "=== AC-62-25 (RED discriminator) — Facilitator > ARCHITECT prose describes the sequential round + citation partitioning ==="
# No exact literal is pinned by either design document for this prose (unlike
# AC-62-32(b)'s quoted §D7 sentence); the two substrings below are this Test
# AI's own oracle, chosen to mirror language already used verbatim elsewhere
# in this cycle's own documents (AC-62-1's criterion text; this verification
# design's own opening line "citation mode partitioned by target mutability").
# Scoped to the ARCHITECT block of the Facilitator section (bounded by the
# VERIFY block header) so the existing unrelated "SEQUENTIAL_FIX" token in the
# VERIFY block cannot satisfy this vacuously.

ARCH_BLOCK="$(awk '/^\*\*ARCHITECT\*\*/{f=1} f{print} /^\*\*VERIFY\*\*/{if(f){exit}}' "$TEAMMATE_CONTRACTS")"
ARCH_HAS_SEQUENTIAL="$(printf '%s' "$ARCH_BLOCK" | grep -qi 'sequential' && echo yes || echo no)"
ARCH_HAS_CITATION_MODE="$(printf '%s' "$ARCH_BLOCK" | grep -qi 'citation mode' && echo yes || echo no)"
assert_true "AC-62-25a: the ARCHITECT contract block describes the sequential test-before-dev round (got: $ARCH_HAS_SEQUENTIAL)" \
  "[ \"$ARCH_HAS_SEQUENTIAL\" = yes ]"
assert_true "AC-62-25b: the ARCHITECT contract block describes the mutability-partitioned citation mode (got: $ARCH_HAS_CITATION_MODE)" \
  "[ \"$ARCH_HAS_CITATION_MODE\" = yes ]"

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
echo ""
echo "=== AC-62-32 (RED discriminator) — D7's retraction reaches all documentary homes (4 parts) ==="

CONTRACTS_MISSING_REASON="$(grep -c 'draft artifact missing' "$TEAMMATE_CONTRACTS" || true)"
assert_true "AC-62-32a: 'draft artifact missing' absent from docs/teammate-contracts.md (got: $CONTRACTS_MISSING_REASON)" \
  "[ \"$CONTRACTS_MISSING_REASON\" -eq 0 ]"

CONTRACTS_ANTECEDENT="$(grep -c 'does not write its design artifact' "$TEAMMATE_CONTRACTS" || true)"
assert_true "AC-62-32a2: the antecedent clause 'does not write its design artifact' absent from docs/teammate-contracts.md (got: $CONTRACTS_ANTECEDENT)" \
  "[ \"$CONTRACTS_ANTECEDENT\" -eq 0 ]"

ARCHITECT_SECTION="$(awk '/^## ARCHITECT/{f=1;next} f && /^## [^A]/{exit} f{print}' "$AUTOFLOW_GUIDE")"
RELOCATION_LITERAL_COUNT="$(printf '%s\n' "$ARCHITECT_SECTION" | grep -cF 'confirm both design artifacts exist and are non-empty before GATE:PLAN' || true)"
assert_true "AC-62-32b: docs/autoflow-guide.md > ARCHITECT states the both-artifacts-exist-and-non-empty precondition (got: $RELOCATION_LITERAL_COUNT)" \
  "[ \"$RELOCATION_LITERAL_COUNT\" -eq 1 ]"

CONTRACTS_FS_SMOKE="$(grep -c "import('node:fs')" "$TEAMMATE_CONTRACTS" || true)"
assert_true "AC-62-32c: the 'fs availability' smoke item's import('node:fs') reference absent from docs/teammate-contracts.md (got: $CONTRACTS_FS_SMOKE)" \
  "[ \"$CONTRACTS_FS_SMOKE\" -eq 0 ]"

# =============================================================================
echo ""
echo "=== AC-62-34 (RED discriminator) — the harness-capability sentence's fifth E8 home ==="

MISSING_ARTIFACT_TOKEN="$(grep -c 'missing-artifact' "$TEAMMATE_CONTRACTS" || true)"
assert_true "AC-62-34: 'missing-artifact' absent from docs/teammate-contracts.md's Automated (mock-runtime regression) paragraph (got: $MISSING_ARTIFACT_TOKEN)" \
  "[ \"$MISSING_ARTIFACT_TOKEN\" -eq 0 ]"


# =============================================================================
echo ""
echo "=== AC-62-36 (RED discriminator, D10) — both scope guards' .claude/workflows/** arm is the manifest-pin oracle, not a substring window ==="

# (i) structural — arm-window-scoped (verification design §7.2a), never a
# whole-file count: a whole-file grep would still see 798's/799's unrelated
# grep -vF arms (.claude/hooks/**, docs/adr/**, …) after a correct D10 edit.
check_arm_structural() {
  local file="$1"
  local window vf_count assert_count hardcode_count has_workflows has_manifest
  window="$(extract_arm_window "$file" | grep -v '^[[:space:]]*#')"
  vf_count="$(printf '%s\n' "$window" | grep -c 'grep -vF' || true)"
  assert_count="$(printf '%s\n' "$window" | grep -cE '^[[:space:]]*assert_true "AC(9|6-scope):' || true)"
  hardcode_count="$(printf '%s\n' "$window" | grep -c 'architect-deliberation\.js' || true)"
  if printf '%s\n' "$window" | grep -qF '.claude/workflows'; then has_workflows=yes; else has_workflows=no; fi
  if printf '%s\n' "$window" | grep -qF 'setup/manifest.json'; then has_manifest=yes; else has_manifest=no; fi
  if [[ "$vf_count" -eq 0 && "$assert_count" -eq 1 && "$hardcode_count" -eq 0 && "$has_workflows" = yes && "$has_manifest" = yes ]]; then
    echo "yes(grep-vF=$vf_count,assert=$assert_count,hardcode=$hardcode_count,workflows-named=$has_workflows,manifest-named=$has_manifest)"
  else
    echo "no(grep-vF=$vf_count,assert=$assert_count,hardcode=$hardcode_count,workflows-named=$has_workflows,manifest-named=$has_manifest)"
  fi
}

S798_36I="$(check_arm_structural "$PROJECT_ROOT/tests/test-issue-798-topology-flip.sh")"
S799_36I="$(check_arm_structural "$PROJECT_ROOT/tests/test-issue-799-inert-cleanup.sh")"
assert_true "AC-62-36(i): both guards' .claude/workflows/** arm window has zero grep -vF filters, exactly one assert_true, zero hardcoded 'architect-deliberation.js', and that assert_true names both .claude/workflows/** and setup/manifest.json (798: $S798_36I; 799: $S799_36I)" \
  "[[ '$S798_36I' == yes* && '$S799_36I' == yes* ]]"

# (iii)/(iv) — unconditional negative controls (#107). Both were once gated on
# a dev/*-issue-62 branch on the ground that the guard's .claude/workflows/**
# arm iterates over the branch's own diff, so the controls were meaningless
# unless that diff touched such a path. That ground held for exactly one of
# them: (iv)'s mutator commits its deletion inside the worktree and therefore
# supplies its own diff, while (iii)'s sha-rewrite was uncommitted and
# contributed nothing to a three-dot diff — the branch gate was supplying its
# premise. (iii)'s mutator is now the hermetic stale-row form above, which
# commits the workflow-file edit it asserts is stale, so both controls carry
# their own premise and neither depends on the host branch.
#
# CI's pull_request checkout has no local `main` branch, only `origin/main` —
# but the child guards (798/799) resolve their own base via a bare
# `git merge-base HEAD main` internally, so their .claude/workflows/** arm
# SKIPs without a local `main` ref and neither control below can produce an
# arm-FAIL. Create the ref (no checkout) so the child guards — and worktrees,
# which share refs — can resolve it; no-op locally where `main` already exists.
if [[ -z "$(cd "$PROJECT_ROOT" && git branch --list main)" ]] && (cd "$PROJECT_ROOT" && git rev-parse --verify origin/main >/dev/null 2>&1); then
  (cd "$PROJECT_ROOT" && git branch main origin/main) || true
fi

# AC-62-36(ii) is retired by issue #103's leaf rule: it re-ran
# tests/test-issue-798-topology-flip.sh and
# tests/test-issue-799-inert-cleanup.sh, each of which carries its own
# `run:` step. The negative controls (iii) and (iv) below are what give
# this lane its teeth, and they drive the real guard file against a real
# mutated on-disk state rather than re-running a green sibling.

# (iii) hermetic negative control (C3, E10/O9 non-mock): commit a workflow-file
# edit in a real detached worktree while leaving its manifest row untouched,
# then run the REAL guard file — never a re-implemented copy of its logic.
OUT_798_STALE="$(guard_result_at_ref_mutated HEAD test-issue-798-topology-flip.sh stale_workflow_manifest_row)"
OUT_799_STALE="$(guard_result_at_ref_mutated HEAD test-issue-799-inert-cleanup.sh stale_workflow_manifest_row)"
M798="$(printf '%s\n' "$OUT_798_STALE" | grep -qE 'FAIL:.*\.claude/workflows' && echo yes || echo no)"
M799="$(printf '%s\n' "$OUT_799_STALE" | grep -qE 'FAIL:.*\.claude/workflows' && echo yes || echo no)"
assert_true "AC-62-36(iii): a .claude/workflows/** file edited and committed in a real detached worktree at HEAD, with its setup/manifest.json row left stale, makes the REAL guard file report FAIL specifically on its .claude/workflows/** arm — not merely its unrelated .claude/hooks/** arm (798: $M798, 799: $M799)" \
  "[ '$M798' = yes ] && [ '$M799' = yes ]"

# (iv) deletion control (C2): both the workflow file AND its manifest
# row are removed in the worktree, closing the empty-vs-empty vacuity
# ("" == "" silently admits) a naive equality would fall into.
OUT_798_DEL="$(guard_result_at_ref_mutated HEAD test-issue-798-topology-flip.sh delete_workflow_and_manifest_row)"
OUT_799_DEL="$(guard_result_at_ref_mutated HEAD test-issue-799-inert-cleanup.sh delete_workflow_and_manifest_row)"
D798="$(printf '%s\n' "$OUT_798_DEL" | grep -qE 'FAIL:.*\.claude/workflows' && echo yes || echo no)"
D799="$(printf '%s\n' "$OUT_799_DEL" | grep -qE 'FAIL:.*\.claude/workflows' && echo yes || echo no)"
assert_true "AC-62-36(iv): deleting the workflow file AND its manifest row in a real detached worktree does not silently admit (empty-vs-empty vacuity, C2) — the REAL guard reports FAIL on its .claude/workflows/** arm (798: $D798, 799: $D799)" \
  "[ '$D798' = yes ] && [ '$D799' = yes ]"


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
assert_true "AC-62-39: setup/manifest.json carries zero 'tests/…' source rows so AC-56-10a/AC-59-9 stay unmoved (got: $MANIFEST_TESTS_ROWS)" \
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
