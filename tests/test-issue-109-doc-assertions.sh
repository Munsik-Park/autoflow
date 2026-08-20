#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: docs/doc-invariant-registry.md tests/adr-0016-conformance-check.sh tests/fixtures/doc-invariants.json tests/manual/ tests/plugin/manual-scenarios-943.md tests/plugin/manual-scenarios.md tests/plugin/verify-install-skill-scripts.sh tests/plugin/verify-package.sh tests/test-issue-798-topology-flip.sh tests/test-issue-799-inert-cleanup.sh
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: auxiliary-asset hygiene cross-file/file-set assertions — Issue #109
# =============================================================================
# Tier-1 scripted assertion suite per verification design
# (.autoflow/issue-109-verification-design.md). Docs/chore change (no jest,
# no npm) — assert_true/assert_false over shell predicates, mirrors
# tests/test-issue-798-topology-flip.sh / tests/test-issue-799-inert-cleanup.sh.
#
# LEAF RULE: this suite reads the CONTENT of tests/test-issue-798-topology-flip.sh,
# tests/test-issue-799-inert-cleanup.sh and tests/adr-0016-conformance-check.sh via
# grep/awk only. It never executes any of them as a subprocess — a sibling's own
# regression is caught by that sibling's own CI step (docs/autoflow-guide.md > RED
# > Leaf rule).
#
# lane: standing — every leg below asserts a permanent state of the tree (files
# absent, files present, literals present in named suites/registry sections,
# carrier ids resolvable), none asserts this cycle's diff. No cycle-arm, no
# retire-with.
#
# Scope (verification design "Acceptance criteria -> verification type ->
# method"): Groups A, C and D's "cycle spec" rows. Group B (the issue-100 M1
# corrected-step literals) is carried as registry data appends to
# tests/fixtures/doc-invariants.json instead (evaluated by
# tests/run-doc-invariants.sh, not by this file — registry §1 defines a data
# append as needing no new script). Cross-cutting composition-oracle rows
# (AC-maintained-docs-no-dangling, AC-manifest-fixed-point,
# AC-registry-run-green, AC-suite-ci-registered,
# AC-suite-step-governed-shape, AC-trigger-correspondence-holds) are existing
# scripts this cycle does not modify and are not re-asserted here.
#
# Group A reconciliation (GATE:PLAN ledger O2 item 1): AC-stale-record-retired
# and AC-retirement-basis-recorded were mutually unsatisfiable as originally
# authored -- see .autoflow/issue-109-verification-design.md's Group A row for
# AC-stale-record-retired (docs/doc-invariant-registry.md excluded from the
# tree-wide sweep) for the applied repair.
#
# RED expectation (pre-change):
#   - AC-stale-record-retired: the `[ ! -f ]` leg FAILs for issue-81/85/99
#     (the three files still exist).
#   - AC-live-record-preserved: PASSes now and stays PASS (guard).
#   - AC-retirement-basis-recorded: FAILs for all six basenames (docs/doc-
#     invariant-registry.md has no ##13 section yet).
#   - AC-plugin-crossref-present / AC-crossref-enumerates-owned-items: FAIL
#     (neither naming suite mentions either complement document yet).
#   - AC-crossref-target-resolves / AC-crossref-stays-in-comment-form: guards,
#     PASS now (vacuously — no reference exists yet to be dangling or
#     mis-formed) and stay PASS after a conforming GREEN.
#   - AC-assertless-header-removed: FAILs for every one of the 13 enumerated
#     headers (798 AC5/AC15; 799 AC1/AC3/AC6/AC7/AC9/AC11; adr-0016 AC4/AC5/
#     AC6/AC-961-5/AC-961-7) -- every `echo "=== <id> "` line is present today.
#   - AC-header-scope-list-consistent: FAILs for the same 13 (their Scope/RED-
#     expectation header rows still name the id today).
#   - AC-carrier-recorded: FAILs for all three suite paths (no ##13 section
#     yet to carry them).
#   - AC-carrier-resolves: guard, re-verifies the design's own Evidence claim
#     that every cited carrier already resolves in the current tree; PASSes
#     now and is not expected to change (a later cycle deleting a cited
#     carrier is what this guards against).
#   - AC-live-assertion-set-preserved: guard (non-vacuity keystone), PASSes
#     now against the checked-in baseline snapshot
#     (tests/fixtures/issue-109-assertion-baseline-{798,799,adr0016}.txt) and
#     is expected to keep passing -- it REDs only if a later edit deletes one
#     of today's assertions.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REGISTRY_MD="$PROJECT_ROOT/docs/doc-invariant-registry.md"
DOC_INVARIANTS_JSON="$PROJECT_ROOT/tests/fixtures/doc-invariants.json"
SUITE_798="$PROJECT_ROOT/tests/test-issue-798-topology-flip.sh"
SUITE_799="$PROJECT_ROOT/tests/test-issue-799-inert-cleanup.sh"
SUITE_ADR0016="$PROJECT_ROOT/tests/adr-0016-conformance-check.sh"
VERIFY_PACKAGE="$PROJECT_ROOT/tests/plugin/verify-package.sh"
VERIFY_INSTALL_SKILL="$PROJECT_ROOT/tests/plugin/verify-install-skill-scripts.sh"

PASS=0; FAIL=0; TESTS=0

# ---------------------------------------------------------------------------
# Helpers (assert_* pattern per tests/test-issue-798-topology-flip.sh)
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

# Level-aware heading extractor (mirrors tests/run-doc-invariants.sh's
# extract_section — stripped-heading exact-text anchor, closes at the next
# same-or-higher-level heading). Used for docs/doc-invariant-registry.md's
# §13 section, which does not exist pre-GREEN (empty output is the correct
# pre-change result, not a bug in this extractor).
extract_section() {          # heading_text file
  local heading="$1" file="$2"
  [ -f "$file" ] || return 0
  awk -v h="$heading" '
    function level(line,   n){ n=0; while(substr(line,n+1,1)=="#") n++; return n }
    !f && /^#{1,6} +/ {
      t=$0; sub(/^#{1,6} +/,"",t); sub(/[ \t]+$/,"",t)
      if (t==h) { f=1; L=level($0); next }
    }
    f {
      if (/^#{1,6} +/ && level($0)<=L) { f=0; next }
      else print
    }
  ' "$file"
}

# A suite's column-1 comment header — everything before its first `set -uo
# pipefail` line (found dynamically, not by a hardcoded line number).
suite_header() {              # file
  local file="$1" n
  n="$(grep -n '^set -uo pipefail' "$file" 2>/dev/null | head -1 | cut -d: -f1)"
  if [ -z "$n" ]; then
    cat "$file"
  else
    sed -n "1,$((n - 1))p" "$file"
  fi
}

# Count of lines in $2 matching id $1 as a bounded token: the id is neither
# preceded nor followed by an alnum/underscore/hyphen character. Excludes a
# compound sibling label (AC10/AC11/AC12 for id AC1; AC6-scope/AC6-ci for id
# AC6) while still matching the id inside a parenthetical annotation like
# "(feat AC6, D5)" or a delimited list like "AC-961-1, AC-961-5, AC-961-7".
bounded_id_count() {          # id text
  local id="$1" text="$2"
  printf '%s\n' "$text" | grep -cE "(^|[^A-Za-z0-9_-])${id}([^A-Za-z0-9_-]|\$)"
}

# Comment-block extractor for the plugin-suite cross-reference blocks: from
# the first line containing $1, through the following contiguous run of
# column-1-or-indented `#` comment lines. Empty output (pre-GREEN, neither
# suite mentions either complement document) is the correct pre-change
# result.
extract_comment_block() {     # anchor_substring file
  local anchor="$1" file="$2"
  [ -f "$file" ] || return 0
  awk -v a="$anchor" '
    BEGIN { f = 0 }
    {
      if (!f && index($0, a) > 0) { f = 1; print; next }
      if (f) {
        if ($0 ~ /^[[:space:]]*#/) { print; next }
        else { f = 0 }
      }
    }
  ' "$file"
}

tree_wide_hits() {            # basename
  local base="$1"
  grep -rIl \
    --exclude-dir=.git \
    --exclude-dir=.autoflow \
    --exclude="doc-invariant-registry.md" \
    -- "$base" "$PROJECT_ROOT" 2>/dev/null || true
}

# =============================================================================
echo ""
echo "=== Group A — retirement of discharged Tier-3 records ==="

for n in 81 85 99; do
  base="issue-${n}-manual-scenarios.md"
  assert_true "AC-stale-record-retired: tests/manual/${base} is absent from the tree" \
    "[ ! -f '$PROJECT_ROOT/tests/manual/${base}' ]"
  hits="$(tree_wide_hits "$base")"
  assert_true "AC-stale-record-retired: no residual reference to ${base} anywhere outside its own §13 discharge record (docs/doc-invariant-registry.md excluded from the sweep)" \
    "[ -z '$hits' ]"
done

for n in 89 93 100; do
  base="issue-${n}-manual-scenarios.md"
  assert_true "AC-live-record-preserved: tests/manual/${base} still exists" \
    "[ -f '$PROJECT_ROOT/tests/manual/${base}' ]"
done

REG13_HEADING="13. Migration provenance — retired-guard dispositions (issue #109)"
REG13_BODY="$(extract_section "$REG13_HEADING" "$REGISTRY_MD")"

for n in 81 85 89 93 99 100; do
  base="issue-${n}-manual-scenarios.md"
  assert_true "AC-retirement-basis-recorded: docs/doc-invariant-registry.md §13 carries a disposition row naming ${base}" \
    "printf '%s\n' \"\$REG13_BODY\" | grep -qF -- '$base'"
done

# =============================================================================
echo ""
echo "=== Group C — plugin manual cross-references ==="

assert_true "AC-plugin-crossref-present: tests/plugin/verify-package.sh names tests/plugin/manual-scenarios.md" \
  "grep -qF 'tests/plugin/manual-scenarios.md' '$VERIFY_PACKAGE'"
assert_true "AC-plugin-crossref-present: tests/plugin/verify-package.sh names tests/plugin/manual-scenarios-943.md" \
  "grep -qF 'tests/plugin/manual-scenarios-943.md' '$VERIFY_PACKAGE'"
assert_true "AC-plugin-crossref-present: tests/plugin/verify-install-skill-scripts.sh names tests/plugin/manual-scenarios-943.md" \
  "grep -qF 'tests/plugin/manual-scenarios-943.md' '$VERIFY_INSTALL_SKILL'"

VP_BLOCK="$(extract_comment_block 'manual-scenarios' "$VERIFY_PACKAGE")"
VIS_BLOCK="$(extract_comment_block 'manual-scenarios-943.md' "$VERIFY_INSTALL_SKILL")"

PLAIN_IDS=("M-1" "M-2" "M-3" "M-4" "M-5" "M-R1" "M-R2" "M-6")
NUM943_IDS=("AC2c" "AC3c" "AC4b" "AD3" "M-3-style residual")

for id in "${PLAIN_IDS[@]}" "${NUM943_IDS[@]}"; do
  assert_true "AC-crossref-enumerates-owned-items: verify-package.sh's naming block enumerates '$id'" \
    "printf '%s\n' \"\$VP_BLOCK\" | grep -qF -- '$id'"
done

for id in "${NUM943_IDS[@]}"; do
  assert_true "AC-crossref-enumerates-owned-items: verify-install-skill-scripts.sh's naming block enumerates '$id'" \
    "printf '%s\n' \"\$VIS_BLOCK\" | grep -qF -- '$id'"
done

# AC-crossref-target-resolves (guard): every tests/plugin/manual-scenarios*.md
# path actually referenced from either naming suite resolves on disk. Empty
# reference set pre-GREEN is a vacuous PASS by construction (nothing to
# dangle yet) — this leg reds only if a future reference is a typo/dangling
# path.
CROSSREF_PATHS="$(grep -ohE 'tests/plugin/manual-scenarios(-943)?\.md' "$VERIFY_PACKAGE" "$VERIFY_INSTALL_SKILL" 2>/dev/null | sort -u)"
CROSSREF_MISSING=""
while IFS= read -r p; do
  [ -z "$p" ] && continue
  [ -f "$PROJECT_ROOT/$p" ] || CROSSREF_MISSING="$CROSSREF_MISSING $p"
done <<< "$CROSSREF_PATHS"
assert_true "AC-crossref-target-resolves: every tests/plugin/manual-scenarios*.md path referenced from verify-package.sh / verify-install-skill-scripts.sh resolves on disk" \
  "[ -z '$CROSSREF_MISSING' ]"

# AC-crossref-stays-in-comment-form (guard): neither naming suite's own
# # ci-subject: header declares a tests/**/*.md path.
CI_SUBJECT_VP="$(grep '^# ci-subject:' "$VERIFY_PACKAGE" || true)"
CI_SUBJECT_VIS="$(grep '^# ci-subject:' "$VERIFY_INSTALL_SKILL" || true)"
assert_true "AC-crossref-stays-in-comment-form: verify-package.sh's # ci-subject: header names no tests/**/*.md path" \
  "! printf '%s\n' \"\$CI_SUBJECT_VP\" | grep -qE 'tests/[^[:space:]]*\.md'"
assert_true "AC-crossref-stays-in-comment-form: verify-install-skill-scripts.sh's # ci-subject: header names no tests/**/*.md path" \
  "! printf '%s\n' \"\$CI_SUBJECT_VIS\" | grep -qE 'tests/[^[:space:]]*\.md'"

# =============================================================================
echo ""
echo "=== Group D — assert-less acceptance-criterion section headers ==="

# (suite_var|echo_prefix|target_id) triples — the 13 headers verified at
# ledger O1 item 2 / this design's Group D target list.
GROUP_D_798=("AC5" "AC15")
GROUP_D_799=("AC1" "AC3" "AC6" "AC7" "AC9" "AC11")
GROUP_D_ADR0016=("AC4" "AC5" "AC6" "AC-961-5" "AC-961-7")

SUITE_798_CONTENT="$(cat "$SUITE_798")"
SUITE_799_CONTENT="$(cat "$SUITE_799")"
SUITE_ADR0016_CONTENT="$(cat "$SUITE_ADR0016")"
SUITE_798_HEADER="$(suite_header "$SUITE_798")"
SUITE_799_HEADER="$(suite_header "$SUITE_799")"
SUITE_ADR0016_HEADER="$(suite_header "$SUITE_ADR0016")"

for id in "${GROUP_D_798[@]}"; do
  assert_true "AC-assertless-header-removed: tests/test-issue-798-topology-flip.sh no longer echoes the assert-less '=== $id ' section header" \
    "! printf '%s\n' \"\$SUITE_798_CONTENT\" | grep -qF -- '=== $id '"
  assert_true "AC-header-scope-list-consistent: tests/test-issue-798-topology-flip.sh's header Scope/RED-expectation block no longer lists $id" \
    "[ \"\$(bounded_id_count '$id' \"\$SUITE_798_HEADER\")\" -eq 0 ]"
done

for id in "${GROUP_D_799[@]}"; do
  assert_true "AC-assertless-header-removed: tests/test-issue-799-inert-cleanup.sh no longer echoes the assert-less '=== $id ' section header" \
    "! printf '%s\n' \"\$SUITE_799_CONTENT\" | grep -qF -- '=== $id '"
  assert_true "AC-header-scope-list-consistent: tests/test-issue-799-inert-cleanup.sh's header Scope/RED-expectation block no longer lists $id" \
    "[ \"\$(bounded_id_count '$id' \"\$SUITE_799_HEADER\")\" -eq 0 ]"
done

for id in "${GROUP_D_ADR0016[@]}"; do
  assert_true "AC-assertless-header-removed: tests/adr-0016-conformance-check.sh no longer echoes the assert-less '=== $id ' section header" \
    "! printf '%s\n' \"\$SUITE_ADR0016_CONTENT\" | grep -qF -- '=== $id '"
done

# AC-header-scope-list-consistent for adr-0016: AC4, AC5 and AC6 are never
# listed individually in this file's header — they are covered only by the
# summary sentence "Every AC1-AC6 heading-presence and in-block check that
# not authored it" (tests/adr-0016-conformance-check.sh header). The bounded-
# token id check (bounded_id_count) deliberately excludes a hyphen-adjacent
# match (needed to exclude AC6-scope/AC6-ci-style compound siblings
# elsewhere), which also excludes "AC6" inside the range token "AC1-AC6" —
# so a per-id check would be vacuously already-true for all three and would
# not RED. The real drift this AC targets here is the range claim itself,
# which overstates coverage once AC4/AC5/AC6 are removed; checked directly.
assert_true "AC-header-scope-list-consistent: tests/adr-0016-conformance-check.sh's header no longer claims blanket AC1-AC6 coverage (AC4/AC5/AC6 narrowed out)" \
  "! printf '%s\n' \"\$SUITE_ADR0016_HEADER\" | grep -qF -- 'AC1-AC6'"
for id in "AC-961-5" "AC-961-7"; do
  assert_true "AC-header-scope-list-consistent: tests/adr-0016-conformance-check.sh's header Scope/RED-expectation block no longer lists $id" \
    "[ \"\$(bounded_id_count '$id' \"\$SUITE_ADR0016_HEADER\")\" -eq 0 ]"
done

for path in "tests/test-issue-798-topology-flip.sh" "tests/test-issue-799-inert-cleanup.sh" "tests/adr-0016-conformance-check.sh"; do
  assert_true "AC-carrier-recorded: docs/doc-invariant-registry.md §13 names $path" \
    "printf '%s\n' \"\$REG13_BODY\" | grep -qF -- '$path'"
done

# AC-carrier-resolves (guard): re-verifies, against the live tree, that every
# carrier the feature design cites for a Group D row already resolves — id-
# shaped carriers as registry ids, the one path-shaped carrier (799 AC11) as
# a path plus its four verbatim assertion-description literals. This reds
# only if a later edit removes a cited registry id or literal out from under
# the §13 row that names it.
CARRIER_IDS=(
  "798-AC5-positive-singlerepo" "798-AC5-negative-multirepo-gone"
  "798-AC15a-no-recurse" "798-AC15b-no-submodule-tree" "798-AC15c-degenerate-prose"
  "799-AC1-neg-wizard" "799-AC1-pos-marketplace" "799-AC1-pos-target"
  "799-AC3D-checklist-neg" "799-AC3D-checklist-pos" "799-AC3D-section-neg"
  "799-AC5D-index-neg" "799-AC5D-index-pos" "799-AC5D-maint-header" "799-AC5D-maint-qualifier"
  "799-AC5G-neg-s11a" "799-AC5G-guard-active-na"
  "799-AC5H-degenerate"
  "adr0016-AC4-a-diagnose-heading" "adr0016-AC5-a-casecollection-heading" "adr0016-AC6-a-followup-heading"
  "adr0016-AC961-5-a-owner-approval" "adr0016-AC961-5-b-readme-accepted"
  "adr0016-AC961-7-a-range" "adr0016-AC961-7-b-date" "adr0016-AC961-7-b-repo" "adr0016-AC961-7-c-registry"
)
REGISTRY_ID_SET="$(jq -r '.invariants[].id' "$DOC_INVARIANTS_JSON" 2>/dev/null)"
for cid in "${CARRIER_IDS[@]}"; do
  assert_true "AC-carrier-resolves: registry id carrier '$cid' resolves in tests/fixtures/doc-invariants.json" \
    "printf '%s\n' \"\$REGISTRY_ID_SET\" | grep -qxF -- '$cid'"
done

CARRIER_799_AC11_LITERALS=(
  "git ls-tree HEAD -- services is empty"
  "git ls-files -s -- services has no 160000 mode row"
  "git submodule status is empty"
  "HEAD .gitmodules path-entry count == 0"
)
for lit in "${CARRIER_799_AC11_LITERALS[@]}"; do
  assert_true "AC-carrier-resolves: 799 AC11's form-2 carrier literal '$lit' greps in tests/test-issue-798-topology-flip.sh" \
    "grep -qF -- '$lit' '$SUITE_798'"
done

# AC-live-assertion-set-preserved (non-vacuity keystone, guard): every
# assertion-description literal in the checked-in baseline snapshot (taken at
# this branch head, before this cycle's Group D edit) still greps in its
# suite's source. Set inclusion, not cardinality — a later cycle may add
# assertions; it must never remove one of these.
check_assertion_set_preserved() {   # baseline_file suite_file suite_label
  local baseline="$1" suite="$2" label="$3" missing=0 line
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if ! grep -qF -- "$line" "$suite"; then
      missing=$((missing + 1))
      echo "    MISSING assertion literal in $label: $line" >&2
    fi
  done < "$baseline"
  [ "$missing" -eq 0 ]
}

assert_true "AC-live-assertion-set-preserved: every baseline assertion-description literal still greps in tests/test-issue-798-topology-flip.sh" \
  "check_assertion_set_preserved '$PROJECT_ROOT/tests/fixtures/issue-109-assertion-baseline-798.txt' '$SUITE_798' 'tests/test-issue-798-topology-flip.sh'"
assert_true "AC-live-assertion-set-preserved: every baseline assertion-description literal still greps in tests/test-issue-799-inert-cleanup.sh" \
  "check_assertion_set_preserved '$PROJECT_ROOT/tests/fixtures/issue-109-assertion-baseline-799.txt' '$SUITE_799' 'tests/test-issue-799-inert-cleanup.sh'"
assert_true "AC-live-assertion-set-preserved: every baseline assertion-description literal still greps in tests/adr-0016-conformance-check.sh" \
  "check_assertion_set_preserved '$PROJECT_ROOT/tests/fixtures/issue-109-assertion-baseline-adr0016.txt' '$SUITE_ADR0016' 'tests/adr-0016-conformance-check.sh'"

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
