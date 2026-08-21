#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/hooks/check-autoflow-gate.sh .github/workflows/e2e-dummy-target.yml README.md docs/INDEX.md docs/autoflow-guide.md docs/external-review-sequencing.md docs/git-workflow.md docs/maintained-docs.md docs/submodule-common-rules.md plugin/autoflow/hooks/check-autoflow-gate.sh setup/SETUP-GUIDE.md setup/manifest.json tests/fixtures/doc-invariants.json tests/manual/issue-799-manual-scenarios.md tests/plugin/verify-e2e-dummy-target.sh
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: inert/delete cleanup RED/GREEN harness — Issue #799
# ([#785-S11b] 비활성화된 multi-repo 기계 일괄 정리)
# =============================================================================
# Tier-1 scripted assertion suite per verification design
# (.autoflow/issue-799-verification-design.md). Docs/chore change (no jest,
# no npm) — mirrors tests/test-issue-798-topology-flip.sh /
# tests/test-issue-797-doc-invocation.sh: assert_true/assert_false over
# grep -F + git diff.
#
# Canonical AC numbering (ledger E4 / feature §4.7 R2 / verification §6 C1):
# feature AC1-AC12 (D-ID-keyed) are the top-level names; the assert labels
# below use the verification design's Group A-H sub-oracle ids, each of which
# suffixes a top-level number with a hyphenated sub-oracle name, bound to
# feature AC1-AC12 by the §6 crosswalk table. One id set binds RED/GREEN.
#
# Scope (verification design §2 Tier-1) — narrowed to what this body executes:
#   AC2-tree      structure-tree spot subset (feat AC2, D2)
#   AC3-guide/common/ext  SUBMODULE-SELFREF-ABSENT + DETACH-REF-PRESENT
#                 (feat AC4/AC5, D4)
#   AC4-guard     no broken host-scoped link introduced (preservation)
#   AC6-ci        CI-ENFORCED (feat AC12, D7)
#
# Migrated out of this file, assertion carried elsewhere (issue #109, registry
# §13.2 — the assert-less section headers were removed). Carriers are
# `tests/fixtures/doc-invariants.json` ids unless noted:
#   README-CONSUMED-PRESENT   → 799-AC1-neg-wizard, 799-AC1-pos-marketplace,
#                               799-AC1-pos-target
#   README-CHECKLIST-CURRENT  → 799-AC3D-checklist-neg, 799-AC3D-checklist-pos,
#                               799-AC3D-section-neg
#   INDEX-INERT-ROUTE-ABSENT / maintained-docs neutralize-in-place
#                             → 799-AC5D-index-neg, 799-AC5D-index-pos,
#                               799-AC5D-maint-header, 799-AC5D-maint-qualifier
#   GITWORKFLOW-DEFERRAL-CLEARED → 799-AC5G-neg-s11a, 799-AC5G-guard-active-na
#   DEGENERATE-PROSE-PRESERVED   → 799-AC5H-degenerate
#   NO-SUBMODULE-REINTRO      → no registry entry; carried by
#                               tests/test-issue-798-topology-flip.sh's four
#                               live AC2a/AC2b/AC3a/AC3b git-plumbing
#                               assertions, which are strictly stronger
#
# Narrowed out of this file by issue #116 (a RED-expectation-only id, assigned
# no registry §13.2 row). Carrier is a `tests/fixtures/doc-invariants.json` id:
#   TEMPLATE-ERA-ABSENT       → 799-AC2-neg-template-era
#
# Not in this file (verification design §2 Tier-2/Tier-3, reuse):
#   AC1-src   README Quick Start <-> setup/SETUP-GUIDE.md step agreement
#             -> tests/manual/issue-799-manual-scenarios.md
#   AC2-pos wording accuracy / AC2-tree exhaustiveness vs `ls`
#             -> tests/manual/issue-799-manual-scenarios.md
#   AC1-e2e   already covered by tests/plugin/verify-e2e-dummy-target.sh
#             (init.sh --target E2E) — reuse, no new harness
#
# RED expectation (pre-change, verification §4 / feature §4.7 non-vacuity
# keystone) — stated for the ids this body executes, and only for those:
#   AC2-tree              FAILs pre-change (the structure tree omits
#                         currently-shipped top-level entries)
#   AC3-guide/common/ext  FAILs pre-change (self-claim present, no #798
#                         qualifier)
#   AC4-guard             preservation guard — PASSes pre- and post-change
#   AC6-ci                becomes GREEN only once the suite + CI wiring land
# Ids narrowed out of this file keep their expectation with their carrier
# (see the disposition blocks above); none is restated here.
#
# Retired in issue #121: the two branch-relative preservation fences (the
# Secondary-marker diff fence and the residual-path new-line fence) and the two
# path-parity scope fences this file used to carry. Each was an un-gated DELTA
# over a merged cycle's own diff, so on any later branch it silently re-aimed at
# that branch. Their dispositions and the carriers that took over — the promoted
# permanent registry entries, the plugin package's byte-parity leg, and the
# manifest regeneration lint's fixed point — are docs/doc-invariant-registry.md §16.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
README_MD="$PROJECT_ROOT/README.md"
AUTOFLOW_GUIDE="$PROJECT_ROOT/docs/autoflow-guide.md"
SUBMODULE_COMMON="$PROJECT_ROOT/docs/submodule-common-rules.md"
EXTERNAL_REVIEW_SEQ="$PROJECT_ROOT/docs/external-review-sequencing.md"
INDEX_MD="$PROJECT_ROOT/docs/INDEX.md"
MAINTAINED_DOCS="$PROJECT_ROOT/docs/maintained-docs.md"
GIT_WORKFLOW="$PROJECT_ROOT/docs/git-workflow.md"

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

# =============================================================================
echo "=== AC2 README-LEGACY-ANNOTATION-ABSENT (feat AC2, D2) ==="

# AC2-tree: spot subset of currently-shipped top-level entries the structure
# tree omits pre-edit (verification §1 Group B AC2-tree automated arm).
assert_true "AC2-tree: README structure tree lists docs/adr/, docs/phases/, .claude/agents/, .claude/workflows/, .github/workflows/, scripts/, tests/, plugin/, setup/manifest.json" \
  "grep -qF 'docs/adr/' '$README_MD' && grep -qF 'docs/phases/' '$README_MD' && grep -qF '.claude/agents/' '$README_MD' && grep -qF '.claude/workflows/' '$README_MD' && grep -qF '.github/workflows/' '$README_MD' && grep -qF 'scripts/' '$README_MD' && grep -qF 'tests/' '$README_MD' && grep -qF 'plugin/' '$README_MD' && grep -qF 'setup/manifest.json' '$README_MD'"

# =============================================================================
echo ""
echo "=== AC4/AC5 SUBMODULE-SELFREF-ABSENT / DETACH-REF-PRESENT (feat AC4/AC5, D4) ==="
# Conditional-presence oracle (verification §1 Group C / §3): a bare
# 'services' token grep would be vacuously GREEN (the string appears in
# filenames and correct generalized prose) — P2. Each file: IF the
# present-tense self-claim literal is still present, THEN a #798/detach
# reference must also be present in the same file.

check_selfref_qualified() {
  local file="$1" label="$2"
  if grep -qF "the host's direct submodule is" "$file"; then
    assert_true "$label: present-tense self-claim co-occurs with a #798/detach reference" \
      "grep -q '#798\|detach' '$file'"
  else
    assert_true "$label: present-tense self-claim literal absent (no qualifier needed)" "true"
  fi
}

check_selfref_qualified "$AUTOFLOW_GUIDE" "AC3-guide"
check_selfref_qualified "$SUBMODULE_COMMON" "AC3-common"
check_selfref_qualified "$EXTERNAL_REVIEW_SEQ" "AC3-ext"

# =============================================================================
echo ""
echo "=== AC4-guard NO-BROKEN-LINK-INTRODUCED (preservation) ==="
# Phase A §3: zero broken links today; expected GREEN both pre- and
# post-change (verification §1 Group D AC4-guard).

broken_link_check() {
  local file="$1"
  local dir
  dir="$(dirname "$file")"
  local broken=""
  while IFS= read -r target; do
    [[ -z "$target" ]] && continue
    # Skip external / anchor-only links.
    case "$target" in
      http://*|https://*|\#*) continue ;;
    esac
    target="${target%%#*}"
    [[ -z "$target" ]] && continue
    if [[ ! -e "$dir/$target" && ! -e "$PROJECT_ROOT/$target" ]]; then
      broken="$broken$file -> $target"$'\n'
    fi
  done < <(grep -oE '\]\(([^)]+)\)' "$file" | sed -E 's/\]\((.*)\)/\1/')
  printf '%s' "$broken"
}

ac4_broken="$(broken_link_check "$INDEX_MD")$(broken_link_check "$MAINTAINED_DOCS")"
if [[ -n "$ac4_broken" ]]; then
  echo "  broken links found:"
  printf '%s' "$ac4_broken" | sed 's/^/    /'
fi
assert_true "AC4-guard: no broken repo-relative link in INDEX.md / maintained-docs.md" \
  "[ -z '$ac4_broken' ]"

# =============================================================================
echo ""
echo "=== AC12 CI-ENFORCED (feat AC12, D7) ==="

CI_HOME="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"
assert_true "AC6-ci: e2e-dummy-target.yml references tests/test-issue-799-inert-cleanup.sh" \
  "grep -qF 'test-issue-799-inert-cleanup.sh' '$CI_HOME'"
assert_true "AC6-ci: e2e-dummy-target.yml paths: trigger lists README.md" \
  "ph=\$(grep -A40 '^ *paths:' '$CI_HOME'); printf '%s\n' \"\$ph\" | grep -qF \"'README.md'\""
assert_true "AC6-ci: e2e-dummy-target.yml paths: trigger lists the edited docs/*.md files" \
  "ph=\$(grep -A40 '^ *paths:' '$CI_HOME'); printf '%s\n' \"\$ph\" | grep -qF 'docs/submodule-common-rules.md' && printf '%s\n' \"\$ph\" | grep -qF 'docs/external-review-sequencing.md' && printf '%s\n' \"\$ph\" | grep -qF 'docs/INDEX.md' && printf '%s\n' \"\$ph\" | grep -qF 'docs/maintained-docs.md' && printf '%s\n' \"\$ph\" | grep -qF 'docs/git-workflow.md'"

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
