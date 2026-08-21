#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: docs/doc-invariant-registry.md tests/fixtures/doc-invariants.json tests/manual/ tests/plugin/manual-scenarios-943.md tests/plugin/manual-scenarios.md tests/plugin/verify-install-skill-scripts.sh tests/plugin/verify-package.sh tests/test-issue-798-topology-flip.sh tests/test-issue-799-inert-cleanup.sh
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
# LEAF RULE: this suite reads the CONTENT of tests/test-issue-798-topology-flip.sh
# and tests/test-issue-799-inert-cleanup.sh via grep/awk only. It never executes
# any of them as a subprocess — a sibling's own regression is caught by that
# sibling's own CI step (docs/autoflow-guide.md > RED > Leaf rule).
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
# Scope addendum (issue #116) — verification design
# .autoflow/issue-116-verification-design.md, "Acceptance criteria ->
# verification type -> method": Group E adds the sub-id-granular
# header-narrowing oracles over tests/test-issue-799-inert-cleanup.sh's
# comment header — the curated stale-spelling and live-id lists, the
# compound/family-glob spelling arms, the issue-#116 carrier trail and its
# CARRIER_IDS closure, the registry §13.2 narrowing-claim composition, and
# this suite's own scope currency.
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
#   - AC-assertless-header-removed: FAILs for every one of the enumerated
#     headers (798 AC5/AC15; 799 AC1/AC3/AC6/AC7/AC9/AC11) -- every
#     `echo "=== <id> "` line is present today.
#   - AC-header-scope-list-consistent: FAILs for the same set (their Scope/
#     RED-expectation header rows still name the id today).
#   - AC-carrier-recorded: FAILs for all three suite paths (no ##13 section
#     yet to carry them).
#   - AC-carrier-resolves: guard, re-verifies the design's own Evidence claim
#     that every cited carrier already resolves in the current tree; PASSes
#     now and is not expected to change (a later cycle deleting a cited
#     carrier is what this guards against).
#   - AC-live-assertion-set-preserved: guard (non-vacuity keystone), PASSes
#     now against the checked-in baseline snapshot
#     (tests/fixtures/ratchet/issue-109-assertion-baseline-{798,799}.txt) and
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
GROUP_D_798=("AC5" "AC6" "AC7" "AC9" "AC15")
GROUP_D_799=("AC1" "AC3" "AC6" "AC7" "AC8" "AC9" "AC10" "AC11")

SUITE_798_CONTENT="$(cat "$SUITE_798")"
SUITE_799_CONTENT="$(cat "$SUITE_799")"
SUITE_798_HEADER="$(suite_header "$SUITE_798")"
SUITE_799_HEADER="$(suite_header "$SUITE_799")"
SUITE_SELF_HEADER="$(suite_header "$PROJECT_ROOT/tests/test-issue-109-doc-assertions.sh")"

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

for path in "tests/test-issue-798-topology-flip.sh" "tests/test-issue-799-inert-cleanup.sh"; do
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
  "799-AC2-neg-template-era"
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
  # Absence guard (issue #122, F5). Without it a missing baseline is a VACUOUS
  # PASS, not a failure: `done < "$baseline"` fails its input redirection, the
  # loop body never runs, `missing` stays 0 and the final predicate is true. A
  # fixture move that misses one consumer would therefore disarm this keystone
  # silently rather than redding it — the precise failure mode this cycle
  # exists to retire. Fail loud, naming the path.
  if [ ! -f "$baseline" ]; then
    echo "    BLOCK in $label: baseline file not found: $baseline" >&2
    return 1
  fi
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
  "check_assertion_set_preserved '$PROJECT_ROOT/tests/fixtures/ratchet/issue-109-assertion-baseline-798.txt' '$SUITE_798' 'tests/test-issue-798-topology-flip.sh'"
assert_true "AC-live-assertion-set-preserved: every baseline assertion-description literal still greps in tests/test-issue-799-inert-cleanup.sh" \
  "check_assertion_set_preserved '$PROJECT_ROOT/tests/fixtures/ratchet/issue-109-assertion-baseline-799.txt' '$SUITE_799' 'tests/test-issue-799-inert-cleanup.sh'"

# =============================================================================
echo ""
echo "=== Group E — issue #116: sub-id-granular header narrowing (799) ==="

# stale-spelling-list (.autoflow/issue-116-verification-design.md
# "stale-spelling-list" table). Each id's pre-change bounded count in the 799
# header is non-zero (verified there); AC-stale-subid-absent requires bounded
# count 0 once D-narrow lands. AC3D-section-neg is excluded -- its only bare
# occurrence is inside the compound spelling covered by
# AC-compound-spelling-absent instead.
STALE_799_IDS=(
  "AC1-neg" "AC1-pos" "AC2-neg" "AC3D-checklist-neg" "AC5D-index-neg"
  "AC5D-maint-neg" "AC5G-neg" "AC5G-guard" "AC5H-degenerate" "AC5H-nosubmod"
)
for id in "${STALE_799_IDS[@]}"; do
  assert_true "AC-stale-subid-absent: tests/test-issue-799-inert-cleanup.sh's header carries no bounded occurrence of '$id'" \
    "[ \"\$(bounded_id_count '$id' \"\$SUITE_799_HEADER\")\" -eq 0 ]"
done

# Compound / family-glob narration forms -- gone even though their expanded
# ids are invisible to the bounded-token check above. The AC1-neg/pos form is
# a deliberately redundant fixed-string arm (both components are already
# bounded-token covered above); the other two pin ids that count 0 as bare
# bounded tokens (AC3D-section-neg, and each of AC5D/AC5G/AC5H as a family).
COMPOUND_799_SPELLINGS=(
  "AC3D-checklist-neg/section-neg"
  "AC1-neg/pos"
  "AC5D/G/H-*"
)
for spelling in "${COMPOUND_799_SPELLINGS[@]}"; do
  assert_true "AC-compound-spelling-absent: tests/test-issue-799-inert-cleanup.sh's header no longer spells '$spelling'" \
    "! printf '%s\n' \"\$SUITE_799_HEADER\" | grep -qF -- '$spelling'"
done

# AC-live-id-preserved (guard, PASS pre- and post-change) -- every id the 799
# body actually executes stays named in its header.
LIVE_799_BARE_IDS=(
  "AC2-tree" "AC3-guide" "AC4-guard" "AC6-ci"
)
for id in "${LIVE_799_BARE_IDS[@]}"; do
  assert_true "AC-live-id-preserved: tests/test-issue-799-inert-cleanup.sh's header still names live id '$id'" \
    "[ \"\$(bounded_id_count '$id' \"\$SUITE_799_HEADER\")\" -ge 1 ]"
done
assert_true "AC-live-id-preserved: tests/test-issue-799-inert-cleanup.sh's header still carries the compound spelling 'AC3-guide/common/ext'" \
  "printf '%s\n' \"\$SUITE_799_HEADER\" | grep -qF -- 'AC3-guide/common/ext'"

# AC-retired-121-id-absent -- the ids whose every arm left the 799 body when
# issue #121 retired that suite's two branch-relative preservation fences and
# its two path-parity scope fences. They are pinned here rather than appended
# to STALE_799_IDS: that array is consumed a SECOND time, by the §13.2
# issue-#116 registry-claim composite, as that claim's operative witness set,
# and its own comment derives its membership from the #116 stale-spelling
# table. Appending a #121 id there would condition a §13.2 claim on ids §13.2
# does not govern. This array has exactly one consumer, the loop below, and its
# assertion states only the property that loop executes.
RETIRED_121_799_IDS=(
  "AC3-guard" "AC3-nores" "AC6-scope"
)
for id in "${RETIRED_121_799_IDS[@]}"; do
  assert_true "AC-retired-121-id-absent: tests/test-issue-799-inert-cleanup.sh's header carries no bounded occurrence of '$id', whose every arm was retired in issue #121" \
    "[ \"\$(bounded_id_count '$id' \"\$SUITE_799_HEADER\")\" -eq 0 ]"
done

# AC-carrier-trail-preserved -- preservation arm (guard, PASS pre- and
# post-change: the existing 13 §13.2-assigned carrier ids stay cited) and
# new-carrier arm (REDs today: the issue-#116 carrier row does not exist yet).
TRAIL_799_CARRIER_IDS=(
  "799-AC1-neg-wizard" "799-AC1-pos-marketplace" "799-AC1-pos-target"
  "799-AC3D-checklist-neg" "799-AC3D-checklist-pos" "799-AC3D-section-neg"
  "799-AC5D-index-neg" "799-AC5D-index-pos" "799-AC5D-maint-header" "799-AC5D-maint-qualifier"
  "799-AC5G-neg-s11a" "799-AC5G-guard-active-na"
  "799-AC5H-degenerate"
)
for cid in "${TRAIL_799_CARRIER_IDS[@]}"; do
  assert_true "AC-carrier-trail-preserved: tests/test-issue-799-inert-cleanup.sh's header still cites carrier '$cid'" \
    "printf '%s\n' \"\$SUITE_799_HEADER\" | grep -qF -- '$cid'"
done
assert_true "AC-carrier-trail-preserved: tests/test-issue-799-inert-cleanup.sh's header cites the issue-#116 carrier '799-AC2-neg-template-era'" \
  "printf '%s\n' \"\$SUITE_799_HEADER\" | grep -qF -- '799-AC2-neg-template-era'"

# AC-carrier-guard-covers-new-row -- membership arm (REDs today: the id is
# not yet a CARRIER_IDS member) and closure arm (guard, vacuously PASS today
# -- every 799-AC* id the header cites is already a CARRIER_IDS member).
assert_true "AC-carrier-guard-covers-new-row: 799-AC2-neg-template-era is a member of CARRIER_IDS" \
  "printf '%s\n' \"\${CARRIER_IDS[@]}\" | grep -qxF -- '799-AC2-neg-template-era'"

CITED_799AC_IDS="$(printf '%s\n' "$SUITE_799_HEADER" | grep -oE '799-AC[A-Za-z0-9_-]*' | sort -u)"
UNGUARDED_799AC=""
while IFS= read -r cid; do
  [ -z "$cid" ] && continue
  printf '%s\n' "${CARRIER_IDS[@]}" | grep -qxF -- "$cid" || UNGUARDED_799AC="$UNGUARDED_799AC $cid"
done <<< "$CITED_799AC_IDS"
assert_true "AC-carrier-guard-covers-new-row: every 799-AC* id cited in tests/test-issue-799-inert-cleanup.sh's header is a CARRIER_IDS member" \
  "[ -z '$UNGUARDED_799AC' ]"

# AC-registry-claim-true (composed, bounded to the 799 suite -- ledger O2) --
# the registry §13.2 narrowing sentence, whitespace-normalized (the sentence
# wraps across two lines in the doc), matches the registry body AND every
# stale/compound spelling above is gone from the 799 header.
REG13_2_BODY="$(extract_section "13.2 Assert-less acceptance-criterion section headers" "$REGISTRY_MD")"
NORMALIZED_REG13_2="$(printf '%s\n' "$REG13_2_BODY" | tr '\n' ' ' | tr -s ' ')"
check_ac116_registry_claim_true() {
  printf '%s' "$NORMALIZED_REG13_2" | grep -qF "narrowed to what the body executes, with the migrated ids annotated by their carrier" || return 1
  local id spelling
  for id in "${STALE_799_IDS[@]}"; do
    [ "$(bounded_id_count "$id" "$SUITE_799_HEADER")" -eq 0 ] || return 1
  done
  for spelling in "${COMPOUND_799_SPELLINGS[@]}"; do
    printf '%s\n' "$SUITE_799_HEADER" | grep -qF -- "$spelling" && return 1
  done
  return 0
}
assert_true "AC-registry-claim-true: docs/doc-invariant-registry.md's §13.2 narrowing claim holds of the 799 suite (normalized text match + stale/compound absence)" \
  "check_ac116_registry_claim_true"

# AC-host-suite-header-current -- this suite's own header names the
# issue-#116 addition it is being asked to police, so it does not itself
# acquire the drift it checks for.
assert_true "AC-host-suite-header-current: tests/test-issue-109-doc-assertions.sh's own header names the issue-#116 scope addendum" \
  "printf '%s\n' \"\$SUITE_SELF_HEADER\" | grep -qF -- 'Scope addendum (issue #116)'"

# Reuse-typed legs (verification design .autoflow/issue-116-verification-design.md):
#   AC-registry-pin-consistent    -> bash scripts/test/check-manifest-regen-clean.sh
#   AC-suite-machine-fields-intact -> bash scripts/test/select-suites.sh +
#                                      bash scripts/test/check-suite-manifest.sh
#   AC-suites-still-green          -> run tests/test-issue-799-inert-cleanup.sh
#                                      and this suite end to end
# No new assertion is written for these three; they are existing scripts run
# separately (see the RED report).

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
