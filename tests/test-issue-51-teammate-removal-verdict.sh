#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/hooks/check-autoflow-gate.sh .github/workflows/e2e-dummy-target.yml docs/adr/0000-adr-template.md docs/adr/0017-teammate-removal-feasibility.md docs/autoflow-guide.md docs/doc-invariant-registry.md docs/submodule-common-rules.md docs/teammate-common-rules.md docs/teammate-contracts.md setup/gen-manifest-hashes.sh setup/manifest.json tests/fixtures/doc-invariants.json tests/fixtures/gate-schema.json tests/manual/issue-51-manual-scenarios.md tests/run-doc-invariants.sh
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: issue #51 — teammate-removal feasibility verdict (ADR-0017)
# (cycle-scoped suite, frozen filename — ledger E5)
# =============================================================================
# Verification design: .autoflow/issue-51-verification-design.md (round-10
# ACCEPT, §8d). AC -> lane -> method table: §1. Ratified registry entry set
# (12 entries, promoted to tests/fixtures/doc-invariants.json at GREEN, in
# the SAME commit that creates the headings they anchor — §4 ordering
# constraint): §5.0. Ratified 17-heading skeleton: §5.1. RED expectation: §6.
#
# Deliverable class: this cycle ships a DECISION DOCUMENT
# (docs/adr/0017-teammate-removal-feasibility.md), not runtime code. AC1-AC7,
# AC10, AC14-AC16 are TEMPORARY discriminators here: once GREEN creates
# the ADR and promotes the matching content to the twelve permanent registry
# entries (origin_issue: 51), the duplicated content-presence checks in this
# file became redundant with the registry runner and were deleted by issue
# #120's cleanup pass (the #43 precedent -
# tests/test-issue-43-report-channel-contract.sh's header); their content is
# carried by those twelve entries, and the per-arm dispositions are recorded
# in docs/doc-invariant-registry.md §17. What remains
# PERMANENTLY in this file (content the registry structurally cannot hold —
# docs/doc-invariant-registry.md rejects any diff/count/delta-shaped
# predicate, and workflow-file / manifest-file assertions are outside the
# registry's ADR/README scope):
#
#   AC8/O1   — manifest composition oracle (real setup/gen-manifest-hashes.sh)
#   AC9/O2   — registry-data state predicates (count, shape, contiguity,
#              direction) read from tests/fixtures/doc-invariants.json with jq.
#              The runner-execution half retired in #122 — carrier: the bare
#              runner step in .github/workflows/contract-suites.yml
#   AC12     — CI wiring (run: step + paths: entries + ordering arm)
#   R51-COUNT / meta guard — origin_issue==51 registry entry count (12) and
#              literal-contiguity/direction-of-predicate meta check
#
# This file once carried a "lane A-delta" tier — AC1(d) and AC6(b)/(c) —
# enforced only on issue #51's own dev branch and printing
# DEFERRED-OBSERVABLE everywhere else. Both members asserted properties of
# issue #51's landed diff against its base, so once that PR merged they were
# inert on every branch the tree will ever see again. #107 retired the tier;
# every assertion below is unconditional. See
# docs/doc-invariant-registry.md §12 (normative status of the array-less
# dev/*-issue-<N> gate) and §12.1 (this file's disposition rows).
#
# RED expectation (this commit — docs/adr/0017-*.md does not exist yet):
#   FAIL (discriminators): AC1(a)(b)(c), AC2, AC3, AC4, AC5, AC7, AC10,
#     AC14, AC15, AC16, AC12 (no run: step / paths: entries yet), O1(b)
#     (no manifest row named for the ADR), O2(b) (origin_issue==51 count is
#     0, not 12).
#   PASS (guards, must stay green throughout): AC6(a) is a discriminator (no
#     ADR to carry the deferral statement) until GREEN; O1(a) regen-clean,
#     true before and after; O2(a) exit 0 + 0 failed, true before and after.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ADR_REL="docs/adr/0017-teammate-removal-feasibility.md"
TEMPLATE="$PROJECT_ROOT/docs/adr/0000-adr-template.md"
WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"
REGISTRY="$SCRIPT_DIR/fixtures/doc-invariants.json"
RUNNER="$SCRIPT_DIR/run-doc-invariants.sh"
MANIFEST="$PROJECT_ROOT/setup/manifest.json"
GEN_MANIFEST="$PROJECT_ROOT/setup/gen-manifest-hashes.sh"
GATE_HOOK="$PROJECT_ROOT/.claude/hooks/check-autoflow-gate.sh"
GATE_SCHEMA="$PROJECT_ROOT/tests/fixtures/gate-schema.json"

PASS=0; FAIL=0; TESTS=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

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

# extract_section mirrors tests/run-doc-invariants.sh's own extractor
# (durable heading anchor, level-aware close, optional section_end,
# bare-`---` thematic-break terminator when no section_end is given).
extract_section() {          # heading_text file [section_end]
  local heading="$1" file="$2" endpat="${3:-}"
  awk -v h="$heading" -v endpat="$endpat" '
    function level(line,   n){ n=0; while(substr(line,n+1,1)=="#") n++; return n }
    !f && /^#{1,6} +/ {
      t=$0; sub(/^#{1,6} +/,"",t); sub(/[ \t]+$/,"",t)
      if (t==h) { f=1; L=level($0); next }
    }
    f {
      if (endpat!="" && /^#{1,6} +/ && $0 ~ endpat)  { f=0; next }
      else if (/^#{1,6} +/ && level($0)<=L)          { f=0; next }
      else if (endpat=="" && /^---[ \t]*$/)          { f=0; next }
      else print
    }
  ' "$file" 2>/dev/null
}

body_has() {                 # body literal match
  local body="$1" literal="$2" match="${3:-fixed}"
  if [ "$match" = "regex" ]; then
    grep -qE -- "$literal" <<<"$body"
  else
    grep -qF -- "$literal" <<<"$body"
  fi
}

echo "=== issue #51 — teammate-removal feasibility verdict (ADR-0017) ==="

# ---------------------------------------------------------------------------
# AC8 / O1 — manifest composition oracle: the REAL setup/gen-manifest-hashes.sh
# driven against an isolated copy of the real tree at HEAD. No fixture
# manifest, no stubbed hasher.
# ---------------------------------------------------------------------------
echo ""
echo "=== AC8 / O1 — manifest composition oracle (real producer) ==="

O1_TMP="$(mktemp -d)"
(cd "$PROJECT_ROOT" && tar --exclude='.git' -cf - .) | (cd "$O1_TMP" && tar -xf -) 2>/dev/null
( cd "$O1_TMP" && bash setup/gen-manifest-hashes.sh >/dev/null 2>&1 )

assert_true "O1(a)-regen-clean: committed setup/manifest.json is byte-identical to a fresh regen" \
  "cmp -s '$O1_TMP/setup/manifest.json' '$MANIFEST'"

O1_ROW_COUNT="$(jq -r --arg src "$ADR_REL" '[.artifacts[] | select(.source == $src)] | length' "$O1_TMP/setup/manifest.json" 2>/dev/null)"
assert_true "O1(b)-named-source-row: regenerated manifest has exactly one artifact row for $ADR_REL (currently ${O1_ROW_COUNT:-0})" \
  "[ \"\${O1_ROW_COUNT:-0}\" -eq 1 ]"

if [ "${O1_ROW_COUNT:-0}" -eq 1 ]; then
  O1_ROW_SHA="$(jq -r --arg src "$ADR_REL" '.artifacts[] | select(.source == $src) | .sha256' "$O1_TMP/setup/manifest.json")"
  O1_FILE_SHA="$(shasum -a 256 "$O1_TMP/$ADR_REL" 2>/dev/null | awk '{print $1}')"
  assert_true "O1(c)-hash-coherence: the ADR's manifest row sha256 matches its on-disk hash" \
    "[ '$O1_ROW_SHA' = '$O1_FILE_SHA' ]"
fi

rm -rf "$O1_TMP"

# ---------------------------------------------------------------------------
# AC9 / O2 — registry-data state predicates over the real
# tests/fixtures/doc-invariants.json. No global total, and no re-execution of
# the runner (retired in #122 — see § 19.2).
# ---------------------------------------------------------------------------
echo ""
echo "=== AC9 / O2 — registry-data state predicates (real registry file) ==="

# O2(a)-exit0 / O2(a)-0failed retired (issue #122): both ran the whole registry
# runner from inside this suite. The property they asserted — the registry's
# permanent invariants hold in the CURRENT tree — is carried by the bare,
# if:-less `run: bash tests/run-doc-invariants.sh` step in
# .github/workflows/contract-suites.yml, and re-running it here is the
# whole-subject re-execution scripts/test/check-suite-leaf.sh's D6 row now
# denies. See docs/doc-invariant-registry.md § 19.2. The registry-DATA
# predicates below are state predicates over the file and stay.

O2_COUNT51="$(jq -r '[.invariants[] | select(.origin_issue==51)] | length' "$REGISTRY")"
assert_true "O2(b)-issue-scoped-count: origin_issue==51 registry entry count is exactly 12 (currently $O2_COUNT51)" \
  "[ '$O2_COUNT51' -eq 12 ]"

O2_SHAPE_BAD="$(jq -r '
  [.invariants[] | select(.origin_issue==51) |
    select(.scope != "permanent" or (.predicate != "present" and .predicate != "absent" and .predicate != "ordered"))] | length
' "$REGISTRY")"
assert_true "O2(d)-shape: every origin_issue==51 entry is scope:permanent with predicate in present|absent|ordered" \
  "[ '$O2_SHAPE_BAD' -eq 0 ]"

O2_NEWLINE_BAD="$(jq -r '
  [.invariants[] | select(.origin_issue==51) |
    ((.literal // "") + " " + (.before // "") + " " + (.after // ""))] |
  map(select(contains("\n"))) | length
' "$REGISTRY")"
assert_true "O2(d)-no-embedded-newline: no origin_issue:51 literal/before/after carries an embedded newline" \
  "[ '$O2_NEWLINE_BAD' = 0 ]"

O2_DIRECTION_BAD=0
while IFS=$'\t' read -r id file section predicate match literal after; do
  [ -n "$id" ] || continue
  srcfile="$PROJECT_ROOT/$file"
  if [ -n "$section" ]; then
    body="$(extract_section "$section" "$srcfile")"
  else
    body="$(cat "$srcfile" 2>/dev/null)"
  fi
  case "$predicate" in
    present)
      body_has "$body" "$literal" "$match" || O2_DIRECTION_BAD=$((O2_DIRECTION_BAD + 1))
      ;;
    ordered)
      { body_has "$body" "$literal" "$match" && body_has "$body" "$after" "$match"; } \
        || O2_DIRECTION_BAD=$((O2_DIRECTION_BAD + 1))
      ;;
    absent)
      body_has "$body" "$literal" "$match" && O2_DIRECTION_BAD=$((O2_DIRECTION_BAD + 1))
      ;;
  esac
done < <(jq -r '.invariants[] | select(.origin_issue==51) |
  [.id, .file, (.section // ""), .predicate, (.match // "fixed"),
   (if .predicate=="ordered" then .before else .literal end),
   (.after // "")] | @tsv' "$REGISTRY")

echo "  (info) O2(e): $O2_DIRECTION_BAD/$O2_COUNT51 origin_issue:51 entries mismatch their predicate direction (0 expected)"
assert_true "O2(e)-direction-aware: every origin_issue:51 entry matches its own predicate direction" \
  "[ '$O2_DIRECTION_BAD' -eq 0 ]"

# ---------------------------------------------------------------------------
# AC12 — CI enforcement: the fixed-literal run: step, both paths: blocks
# (suite + manual-scenarios file), and the ordering arm (below the runner
# step's name-located line).
# ---------------------------------------------------------------------------
echo ""
echo "=== AC12 — CI enforcement (workflow run: step + paths: + ordering) ==="

SUITE_REL="tests/test-issue-51-teammate-removal-verdict.sh"
MANUAL_REL="tests/manual/issue-51-manual-scenarios.md"

assert_true "AC12-run-step: workflow has a fixed run: step invoking $SUITE_REL" \
  "grep -qE 'run: bash tests/test-issue-51-teammate-removal-verdict\\.sh' '$WORKFLOW'"

# Capture-then-match (docs/submodule-common-rules.md:212, issues #964/#973):
# awk's buffered output piped directly into a short-circuiting `grep -q`
# consumer can SIGPIPE the producer under `set -o pipefail`, flipping a
# logically-passing assertion to a flaky FAIL. Capture each block once, then
# match the captured string.
PR_PATHS_CTX="$(awk '/^  pull_request:/{f=1} /^  push:/{f=0} f' "$WORKFLOW")"
# Bounded at the next top-level key (e.g. `permissions:`) — an unbounded
# capture ran to EOF and let a match against a LATER `run:` step (which also
# names the suite/manual file) silently stand in for a `paths:` entry,
# masking a deleted paths: row (mutation-tested finding, GATE:QUALITY E36).
PUSH_PATHS_CTX="$(awk '/^  push:/{f=1;next} /^[A-Za-z]/{f=0} f' "$WORKFLOW")"
export PR_PATHS_CTX PUSH_PATHS_CTX

assert_true "AC12-pr-paths-suite: pull_request paths: names $SUITE_REL" \
  "printf '%s\n' \"\$PR_PATHS_CTX\" | grep -qF '$SUITE_REL'"
assert_true "AC12-push-paths-suite: push paths: names $SUITE_REL" \
  "printf '%s\n' \"\$PUSH_PATHS_CTX\" | grep -qF '$SUITE_REL'"
assert_true "AC12-pr-paths-manual: pull_request paths: names $MANUAL_REL" \
  "printf '%s\n' \"\$PR_PATHS_CTX\" | grep -qF '$MANUAL_REL'"
assert_true "AC12-push-paths-manual: push paths: names $MANUAL_REL" \
  "printf '%s\n' \"\$PUSH_PATHS_CTX\" | grep -qF '$MANUAL_REL'"

RUNNER_LINE="$(grep -n "name: Run doc-invariant registry runner (#951)" "$WORKFLOW" | head -1 | cut -d: -f1)"
SUITE_LINE="$(grep -nE "run: bash tests/test-issue-51-teammate-removal-verdict\\.sh" "$WORKFLOW" | head -1 | cut -d: -f1)"
assert_true "AC12(c)-ordering: the new run: step's line is below the doc-invariant registry runner step's line (runner=$RUNNER_LINE, this cycle=${SUITE_LINE:-absent})" \
  "[ -n '$RUNNER_LINE' ] && [ -n '${SUITE_LINE:-}' ] && [ '${SUITE_LINE:-0}' -gt '$RUNNER_LINE' ]"

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
