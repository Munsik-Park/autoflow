#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: Composition oracle — verification-design shared-state requirement,
# Issue #27 (cycle-scoped)
# =============================================================================
# Cycle-scoped DELTA/count guards per the verification design
# (.autoflow/issue-27-verification-design.md §0.2 lane table, §2 Red plan).
# Every permanent STATE assertion for this issue is a data append to
# tests/fixtures/doc-invariants.json (32 entries, ids `27-AC*`; RED-time
# section-anchor note below). Only the assertions the registry structurally
# CANNOT express live here: tests/run-doc-invariants.sh:111 rejects any
# predicate that is not present|absent|ordered at load time, so
# count/delta/diff-shaped guards are cycle-lane by construction
# (docs/doc-invariant-registry.md §1/§2).
#
# RED-authoring note on the registry entries' section anchor (deviation from
# the verification design's stated plan). The verification design's §1.1
# names `section: "Composition oracle"` as the anchor for the AC-27-1..27,
# AC-27-12/23/27 registry entries. At RED-authoring time that heading does
# not exist yet (F1 ships it at GREEN) — B13 measured `grep -c '^#### '` = 0
# at HEAD. tests/run-doc-invariants.sh step 0b treats a 0-match section
# anchor as a load-time BLOCK (dangling anchor), not a per-entry FAIL, and
# the BLOCK aborts the WHOLE registry lane before any entry is evaluated —
# the exact defect class the verification design's own R3-a section
# identified for the withdrawn AC-27-24/25 (GATE:PLAN heading). Unlike
# AC-27-24/25, "Composition oracle" is not withdrawn — F1 creates it at
# GREEN — so dropping the entries is not the right fix. Instead these
# entries are scoped to the EXISTING `### Output artifacts` anchor (present
# at HEAD; DR-0 in the feature design already verified it unique). Because
# `#### Composition oracle` is inserted as a child subsection of
# `### Output artifacts` (level-aware `extract_section`, level 4 nests inside
# level 3, closing only at the next level-<=3 heading —
# `### Testability-driven design`), the new subsection's text is included in
# the `### Output artifacts` body once F1 ships it, so the entries still
# discriminate correctly and become permanent-scope-safe without a dangling
# anchor. Verified empirically this round: with this scoping,
# `bash tests/run-doc-invariants.sh` reports 184/216 passed (32 new FAILs,
# zero regression among the 184 pre-existing entries) — see AC-27-22 below.
# (Historical, RED-phase note: the 184 baseline is this cycle's own; a later
# VERIFY retired an unrelated #26 registry entry, so AC-27-22 itself now
# derives its expected pre-existing count from the registry rather than a
# fixed number — see the comment at AC-27-22's own definition below.)
#
#   AC-27-2 (count half) — fence (PASS pre+post, NOT a RED discriminator):
#                     the `REQUIRED`-as-tag token count in the shipped files
#                     (docs/autoflow-guide.md, docs/teammate-contracts.md,
#                     CLAUDE.md) stays at baseline B1 (0/0/0). DR-4 (feature
#                     design §2.5): the rule text uses `[MUST]`, never the
#                     token `REQUIRED`.
#   AC-27-7           — RED discriminator: the new section carries no
#                     stack-specific technology token (MongoDB,
#                     mongodb-memory-server, jest, pytest) outside its
#                     example clause. At RED the section itself does not yet
#                     exist, so the existence sub-check (not a vacuous
#                     zero-token count) is what fails.
#   AC-27-9           — preservation fence (PASS pre+post, NOT a RED
#                     discriminator): VERIFY step 4 (mock-boundary fidelity
#                     check) is untouched — neither its literal text nor any
#                     diff hunk touches it.
#   AC-27-13          — over-build fence (PASS pre+post): with F4 withdrawn,
#                     no GATE:PLAN rubric changes ship at all — row count
#                     stays 5 (B3), thresholds and the Regressions-line
#                     `max N×` multiset (B5) stay unchanged.
#   AC-27-14          — bounded-runtime fence (PASS pre+post): the cycle
#                     diff's `.claude/` subset is exactly
#                     `{.claude/workflows/architect-deliberation.js}`;
#                     `.claude/hooks/check-autoflow-gate.sh` is untouched.
#   AC-27-20          — composition oracle for S8 (fence, PASS pre+post): the
#                     `workflow-regression` harness
#                     (`node test/workflows/run.mjs`) still loads, executes,
#                     and drives its convergence loop — exit 0, final line
#                     `all workflow regression tests passed`, `ok`-line count
#                     == B14 (31); `node --check` retained as the cheaper
#                     parse-only subset.
#   AC-27-21          — composition oracle for S9. RED-time finding: at HEAD
#                     `setup/manifest.json`'s three registered-source hashes
#                     (docs/autoflow-guide.md, docs/teammate-contracts.md,
#                     .claude/workflows/architect-deliberation.js) already
#                     match their current `shasum -a 256` (empirically
#                     verified this round), so this check PASSES at RED —
#                     reclassified here as a fence (PASS pre+post), not the
#                     RED discriminator the verification design's §1 row
#                     predicted. Investigated per the RED task's own
#                     instruction ("a new test that passes at HEAD ... —
#                     investigate before reporting"): the verification
#                     design's "Fails at RED because S1/S2/S8/S10/S11 change
#                     registered sources" reasoning describes a state that
#                     exists only mid-GREEN (after F1/F2/F3/F5 edit the
#                     sources but before `setup/gen-manifest-hashes.sh`
#                     regenerates), not at RED-confirmation time, when no
#                     GREEN edit has landed yet. The guard is kept — it still
#                     protects the Change Surface Rules > Derived artifacts
#                     obligation that GREEN must satisfy in the same commit —
#                     just correctly reclassified.
#   AC-27-22          — composition oracle for S4 (fence, PASS pre+post): the
#                     184 pre-existing registry invariants stay PASS, run
#                     through the REAL runner, alongside this cycle's 32 new
#                     (expected-FAIL-at-RED) `27-AC*` entries. Checks the
#                     184-entry subset independently of the new entries'
#                     verdicts, since the new entries make the runner's own
#                     exit code non-zero at RED by design.
#   AC-CI-a/b/c       — RED discriminators: this suite is wired into
#                     .github/workflows/e2e-dummy-target.yml (both `paths:`
#                     trigger blocks + a `run:` step), #798/#799/#800/#843/#26
#                     precedent. Confirmed FAIL before registration was
#                     added, then added within this same RED phase (S7 is a
#                     Test-AI-owned surface per the verification design
#                     §0.1), so they read PASS by the end of RED — this is
#                     expected (S7 is the Test AI's own artifact, not
#                     something GREEN produces).
#   AC-CI-d           — COUNT half: the manual-scenario file
#                     (tests/manual/issue-27-manual-scenarios.md) is
#                     registered in BOTH `paths:` blocks (>=2 occurrences).
#                     Count-shaped → cycle lane (the registry's `ordered`
#                     predicate resolves only the first match of each anchor
#                     and cannot express "in both blocks").
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
GUIDE="$PROJECT_ROOT/docs/autoflow-guide.md"
CONTRACTS="$PROJECT_ROOT/docs/teammate-contracts.md"
WORKFLOW_JS="$PROJECT_ROOT/.claude/workflows/architect-deliberation.js"
MANIFEST="$PROJECT_ROOT/setup/manifest.json"
CI_WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"
REGISTRY_RUNNER="$PROJECT_ROOT/tests/run-doc-invariants.sh"
BASEREF_LIB="$PROJECT_ROOT/tests/lib/base-ref.sh"

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

# Level-aware section extractor, mirroring tests/run-doc-invariants.sh's
# extract_section (same repo convention: cycle suites reimplement rather than
# source the registry runner's internals, per tests/test-issue-26-*.sh).
extract_section() {          # heading_text file
  local heading="$1" file="$2"
  awk -v h="$heading" '
    function level(line,   n){ n=0; while(substr(line,n+1,1)=="#") n++; return n }
    !f && /^#{1,6} +/ {
      t=$0; sub(/^#{1,6} +/,"",t); sub(/[ \t]+$/,"",t)
      if (t==h) { f=1; L=level($0); next }
    }
    f {
      if (/^#{1,6} +/ && level($0)<=L)          { f=0; next }
      else if (/^---[ \t]*$/)                    { f=0; next }
      else print
    }
  ' "$file"
}

# Extracts the VERIFY step-4 (Mock-boundary fidelity check) block's own body
# — from its own line through (excluding) the closing code-fence line. Scoped
# to exactly that block, unlike a whole-file diff, so an unrelated line
# elsewhere in the file that happens to contain the same cross-reference
# literal (AC-27-8's complementarity paragraph, which the composition-oracle
# rule is required to carry per feature design §2.4/DR-3) cannot false-
# positive this preservation fence. Fixed by VERIFY (issue #27 cause-branch:
# the prior whole-file-diff form flagged AC-27-8's own cross-reference line
# as a step-4 mutation).
extract_step4_block() {      # file
  awk '/^4\. Mock-boundary fidelity check \(Test AI\):/{f=1} f{ if ($0 ~ /^```/) exit; print }' "$1"
}

count_heading() {            # anchor file
  local anchor="$1" file="$2"
  awk -v h="$anchor" '
    /^#{1,6} +/ {
      t=$0; sub(/^#{1,6} +/,"",t); sub(/[ \t]+$/,"",t)
      if (t==h) c++
    }
    END { print c+0 }
  ' "$file"
}

# =============================================================================
echo "=== AC-27-2 (count half, fence) — REQUIRED-as-tag token count unchanged in shipped files ==="

B1_EXPECTED="0 0 0"
GOT="$(grep -c REQUIRED "$GUIDE" || true) $(grep -c REQUIRED "$CONTRACTS" || true) $(grep -c REQUIRED "$CLAUDE_MD" || true)"
assert_true "AC-27-2: REQUIRED-as-tag token count in docs/autoflow-guide.md + docs/teammate-contracts.md + CLAUDE.md stays '$B1_EXPECTED' (got: '$GOT')" \
  "[ \"$GOT\" = \"$B1_EXPECTED\" ]"

# =============================================================================
echo ""
echo "=== AC-27-7 (RED discriminator) — no stack-specific technology token in the new section ==="

HEADING_COUNT="$(count_heading "Composition oracle" "$GUIDE")"
assert_true "AC-27-7-anchor: docs/autoflow-guide.md carries exactly one '#### Composition oracle' heading" \
  "[ \"$HEADING_COUNT\" -eq 1 ]"

if [ "$HEADING_COUNT" -eq 1 ]; then
  SECTION_BODY="$(extract_section "Composition oracle" "$GUIDE")"
  STACK_TOKEN_COUNT="$(printf '%s\n' "$SECTION_BODY" | grep -cE 'MongoDB|mongodb-memory-server|jest|pytest' || true)"
  assert_true "AC-27-7: no stack-specific token (MongoDB/mongodb-memory-server/jest/pytest) in the Composition oracle section body (got: $STACK_TOKEN_COUNT)" \
    "[ \"$STACK_TOKEN_COUNT\" -eq 0 ]"
else
  echo "  BLOCK: AC-27-7 stack-token count unmeasurable (section anchor missing) — counted FAIL, never skipped"
  TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
fi

# =============================================================================
echo ""
echo "=== AC-27-9 (preservation fence, PASS pre+post) — VERIFY step 4 untouched ==="

assert_true "AC-27-9-literal: VERIFY step-4 block still present verbatim" \
  "grep -qF 'Mock-boundary fidelity check (Test AI)' '$GUIDE'"

if [[ ! -f "$BASEREF_LIB" ]]; then
  echo "  BLOCK: tests/lib/base-ref.sh missing — AC-27-9's diff half is base-dependent and cannot be evaluated"
  TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
else
  # shellcheck source=/dev/null
  . "$BASEREF_LIB"
  BASE_REF="$(cd "$PROJECT_ROOT" && resolve_base_ref "${ISSUE_27_BASE_REF:-}" || true)"
  if [[ -z "$BASE_REF" ]]; then
    echo "  BLOCK: no comparison base resolvable (override / GITHUB_BASE_REF / origin/main / main all unavailable) — AC-27-9's diff half counted FAIL, never skipped"
    TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
  else
    HEAD_STEP4="$(extract_step4_block "$GUIDE")"
    BASE_STEP4="$(cd "$PROJECT_ROOT" && git show "$BASE_REF:docs/autoflow-guide.md" 2>/dev/null | awk '/^4\. Mock-boundary fidelity check \(Test AI\):/{f=1} f{ if ($0 ~ /^```/) exit; print }')"
    if [ -n "$HEAD_STEP4" ] && [ "$HEAD_STEP4" = "$BASE_STEP4" ]; then
      STEP4_UNCHANGED=true
    else
      STEP4_UNCHANGED=false
    fi
    assert_true "AC-27-9-diff: VERIFY step-4 block content byte-identical between $BASE_REF and HEAD (scoped to the block itself, not the whole-file diff)" \
      "[ \"$STEP4_UNCHANGED\" = true ]"
  fi
fi

# =============================================================================
echo ""
echo "=== AC-27-13 (over-build fence, PASS pre+post) — no GATE:PLAN rubric change at all ==="

GATEPLAN_ROWS="$(awk '/^### Scoring \(5 items/{f=1;next} f && /^### ADR-conformance/{exit} f && /^\|/ && !/^\|-/ && !/^\| Item \| Criterion \|/{c++} END{print c+0}' "$GUIDE")"
assert_true "AC-27-13a: GATE:PLAN scoring-table row count == 5 (B3) (got: $GATEPLAN_ROWS)" \
  "[ \"$GATEPLAN_ROWS\" -eq 5 ]"

REG_LINE_NO="$(grep -n '^\*\*Regressions\*\*' "$CLAUDE_MD" | head -1 | cut -d: -f1)"
if [[ -z "$REG_LINE_NO" ]]; then
  assert_true "AC-27-13b-anchor: CLAUDE.md carries a '**Regressions**' line" "false"
  echo "  BLOCK: AC-27-13b multiset unmeasurable (anchor missing)"
  TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
else
  CAP_MULTISET="$(sed -n "${REG_LINE_NO}p" "$CLAUDE_MD" | grep -o 'max [0-9]*×' | sort | uniq -c | awk '{print $2, $3 "=" $1}' | paste -sd' ' -)"
  EXPECTED_MULTISET="max 2×=5 max 3×=2 max 7×=1"
  assert_true "AC-27-13b: Regressions-line 'max N×' multiset unchanged ('$EXPECTED_MULTISET') (got: '$CAP_MULTISET')" \
    "[ \"\$(printf '%s' '$CAP_MULTISET')\" = \"\$(printf '%s' '$EXPECTED_MULTISET')\" ]"
fi

assert_true "AC-27-13c: 'avg ≥ 7.5' threshold literal still present" "grep -qF 'avg ≥ 7.5' '$CLAUDE_MD'"
assert_true "AC-27-13d: 'each ≥ 7' threshold literal still present" "grep -qF 'each ≥ 7' '$CLAUDE_MD'"

# =============================================================================
# AC-27-14 (retired, #64): the ".claude/ diff confined to
# architect-deliberation.js / hook not in cycle diff" fence was a #27
# cycle-scope seal; it blocked every legitimate later .claude/ change
# (change-detector anti-pattern) and was removed in the #64 hook-fix PR.

# =============================================================================
echo ""
echo "=== AC-27-20 (composition oracle for S8, fence, PASS pre+post) — workflow-regression harness ==="

# B14 update (GATE:QUALITY FAIL #4 / ledger L18, issue #56, user-approved same-PR sibling
# fix): #56 added six run.mjs tests (31 -> 37). Bumped the literal here rather than
# branch-scoping it per the ea68a4c idiom (tests/test-issue-7-oracle-hardening.sh AC-7-7b):
# issue #27 is long since merged and has no live dev branch to scope to, so a branch-scoped
# form here would defer PERMANENTLY (never assert again), silently disabling this fence
# rather than keeping it meaningful — unlike #56/#7's own cycle-scoped assertions, this one
# still functions as a standing shared-harness regression lock across every cycle, not a
# single cycle's own baseline. A plain literal bump will need repeating by each future
# cycle that adds run.mjs tests; that recurring cost is accepted as the trade-off for
# keeping the check live (a structural fix — e.g. retiring this duplicate check in favor of
# #56's own branch-scoped AC-56-8 fence — is a candidate follow-up, out of this cycle's
# scope).
# B14 update (issue #59, D11/D18): #59 added six run.mjs tests for the adoption-side
# evidence discipline (37 -> 43). Same reasoning as above — the literal is bumped in the
# same commit as the run.mjs addition, keeping the plain-literal unconditional form. The
# value has two homes (D18): this literal and EXPECTED_OK in
# tests/test-issue-59-adoption-evidence-discipline.sh; a future test add or remove edits
# both in one commit, and that suite's AC-59-14c asserts the two agree.
# B14 update (issue #67): the ARCHITECT deliberation record redesign (register +
# dispositions) retired two run.mjs tests (AC-62-12, AC-62-28i) and added the register/
# disposition lane-A discriminators, net measured 43 -> 80. Bumped in the same commit as
# GREEN's architect-deliberation.js change, per this suite's own precedent above.
# B14 update (issue #69): verification-depth justification added two run.mjs tests
# (AC-69-prompt-delivery, AC-69-accept-gating — the Test-AI Draft/round-prompt delivery
# assertions), net measured 80 -> 82. Bumped in the SAME commit as the RED-lane run.mjs
# addition (not GREEN) per issue #69's verification design "harness ok-count pin" note.
HARNESS_OUT="$(cd "$PROJECT_ROOT" && node test/workflows/run.mjs 2>&1)"
HARNESS_EXIT=$?
OK_COUNT="$(printf '%s\n' "$HARNESS_OUT" | grep -c '^\s*ok' || true)"
assert_true "AC-27-20a: node test/workflows/run.mjs exits 0" "[ $HARNESS_EXIT -eq 0 ]"
assert_true "AC-27-20b: harness reports 'all workflow regression tests passed'" \
  "printf '%s\n' \"\$HARNESS_OUT\" | grep -qF 'all workflow regression tests passed'"
assert_true "AC-27-20c: harness ok-line count == B14 (82) (got: $OK_COUNT)" "[ \"$OK_COUNT\" -eq 82 ]"
assert_true "AC-27-20d: node --check .claude/workflows/architect-deliberation.js exits 0 (cheaper subset)" \
  "node --check '$WORKFLOW_JS'"

# =============================================================================
echo ""
echo "=== AC-27-21 (composition oracle for S9, reclassified fence, PASS pre+post) — manifest freshness ==="

# AC-27-21a was a global artifact-count fence (== B6, 47) — the retired
# ADR-0016 AC-R3-c count-guard class (docs/doc-invariant-registry.md:113):
# it reds on any legitimate later cycle's manifest addition/removal (e.g.
# issue #51's ADR-0017 row), not just a #27 regression. Converted to the
# documented drift-immune shape: a state predicate over the three NAMED
# sources this cycle actually registers/edits, matching what B6 protected
# (the "Manifest freshness" comment block above) — same shape as
# tests/test-issue-43-report-channel-contract.sh:134-143's issue-scoped
# precedent, applied here to named sources rather than an origin_issue tag
# (the manifest schema carries no origin_issue field).
MANIFEST_ARTIFACT_COUNT="$(jq '.artifacts | length' "$MANIFEST")"
echo "  (info) AC-27-21a: setup/manifest.json artifact count is currently $MANIFEST_ARTIFACT_COUNT (informational — not asserted; see conversion note above)"

AC_27_21A_NAMED_SOURCES=(
  "docs/autoflow-guide.md"
  "docs/teammate-contracts.md"
  ".claude/workflows/architect-deliberation.js"
)
AC_27_21A_BAD=0
for src in "${AC_27_21A_NAMED_SOURCES[@]}"; do
  cnt="$(jq -r --arg s "$src" '[.artifacts[] | select(.source == $s)] | length' "$MANIFEST")"
  if [ "$cnt" -ne 1 ]; then
    AC_27_21A_BAD=$((AC_27_21A_BAD + 1))
    echo "  (info) AC-27-21a: manifest artifact row count for '$src' == $cnt (expected 1)"
  fi
done
assert_true "AC-27-21a: setup/manifest.json carries exactly one artifact row for each of this cycle's three registered sources (drift-immune: named-source state predicate, not a global count)" \
  "[ '$AC_27_21A_BAD' -eq 0 ]"

STALE=""
while IFS=$'\t' read -r src rec_hash; do
  [ -z "$src" ] && continue
  # setup/manifest.json's own self-entry carries a null sha256 (the manifest
  # cannot record its own post-regeneration hash in advance) — not a
  # freshness check target, per setup/gen-manifest-hashes.sh.
  [ "$src" = "setup/manifest.json" ] && continue
  cur_hash="$(shasum -a 256 "$PROJECT_ROOT/$src" 2>/dev/null | awk '{print $1}')"
  if [ "$cur_hash" != "$rec_hash" ]; then
    STALE="$STALE $src"
  fi
done < <(jq -r '.artifacts[] | select(.kind=="copy") | [.source, .sha256] | @tsv' "$MANIFEST")

assert_true "AC-27-21b: every copy-kind artifact's recorded sha256 matches its current source (stale:${STALE:- none})" \
  "[ -z \"$STALE\" ]"

# =============================================================================
echo ""
echo "=== AC-27-22 (composition oracle for S4, fence, PASS pre+post) — pre-existing registry invariants stay PASS ==="
# B2 (184) was the pre-existing count measured at this cycle's HEAD (verification
# design §0.4). It is no longer the live baseline: issue #27's own VERIFY
# (GATE:QUALITY Impact-scope regression) retired the stale #26 cycle-scoped
# guard's dangling registry entry (26-AC15a), which is an orthogonal,
# legitimately-landed change on this same branch, not a regression. Deriving
# the expected pre-existing count from the registry itself (total minus this
# cycle's own 27-AC* entries) keeps this fence meaningful against future
# unrelated registry churn instead of re-hardcoding a new magic number.

REGISTRY_OUT="$(bash "$REGISTRY_RUNNER" 2>&1)"
PRE_EXISTING_FAILS="$(printf '%s\n' "$REGISTRY_OUT" | grep '^  FAIL: ' | awk '{print $2}' | grep -cv '^27-AC' || true)"
PRE_EXISTING_PASSES="$(printf '%s\n' "$REGISTRY_OUT" | grep '^  PASS: ' | awk '{print $2}' | grep -cv '^27-AC' || true)"
PRE_EXISTING_TOTAL="$(jq '[.invariants[] | select(.id | startswith("27-AC") | not)] | length' "$PROJECT_ROOT/tests/fixtures/doc-invariants.json")"
assert_true "AC-27-22a: no pre-existing (non-27-AC) registry entry FAILs (got: $PRE_EXISTING_FAILS)" \
  "[ \"$PRE_EXISTING_FAILS\" -eq 0 ]"
assert_true "AC-27-22b: pre-existing (non-27-AC) registry PASS count == every pre-existing (non-27-AC) entry (got: $PRE_EXISTING_PASSES of $PRE_EXISTING_TOTAL)" \
  "[ \"$PRE_EXISTING_PASSES\" -eq \"$PRE_EXISTING_TOTAL\" ]"

# =============================================================================
echo ""
echo "=== AC-CI-a/b/c (S5 self-registration) + AC-CI-d (S6 count) — e2e-dummy-target.yml ==="

if [[ -f "$CI_WORKFLOW" ]]; then
  assert_true "AC-CI-a: e2e-dummy-target.yml references test-issue-27-composition-oracle" \
    "grep -q 'test-issue-27-composition-oracle' '$CI_WORKFLOW'"
  assert_true "AC-CI-b: reference appears in a 'paths:' trigger block" \
    "ctx=\$(grep -B90 'test-issue-27-composition-oracle' '$CI_WORKFLOW'); printf '%s\n' \"\$ctx\" | grep -q '^ *paths:'"
  assert_true "AC-CI-c: reference appears in a 'run:' step" \
    "ctx=\$(grep -A2 'test-issue-27-composition-oracle' '$CI_WORKFLOW'); printf '%s\n' \"\$ctx\" | grep -q 'run: bash tests/test-issue-27-composition-oracle.sh'"
  assert_true "AC-CI-d: manual-scenario file registered in BOTH paths: blocks (>=2 occurrences)" \
    "[ \"\$(grep -cF \"'tests/manual/issue-27-manual-scenarios.md'\" '$CI_WORKFLOW')\" -ge 2 ]"
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
