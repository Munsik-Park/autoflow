#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/hooks/check-autoflow-gate.sh .github/workflows/e2e-dummy-target.yml README.md docs/INDEX.md docs/autoflow-guide.md docs/external-review-sequencing.md docs/git-workflow.md docs/maintained-docs.md docs/submodule-common-rules.md plugin/autoflow/hooks/check-autoflow-gate.sh setup/SETUP-GUIDE.md setup/manifest.json tests/fixtures/doc-invariants.json tests/manual/issue-799-manual-scenarios.md tests/plugin/verify-e2e-dummy-target.sh
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# out-of-tree-inputs: yes
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
#   AC3-guard     SECONDARY-PRESERVED (guard, feat AC8)
#   AC3-nores     no doc points at the residual untracked services/ working copy
#   AC4-guard     no broken host-scoped link introduced (preservation)
#   AC6-scope     path-parity scope arms: .claude/hooks/** parity and the
#                 #62 D10 .claude/workflows/** manifest-sha accumulator (feat AC10)
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
#   AC3-guard, AC4-guard  preservation guards — PASS pre- and post-change
#   AC3-nores             changed-surface guard — PASSes pre- and post-change
#   AC6-scope, AC6-ci     become GREEN only once the suite + CI wiring land
# Ids narrowed out of this file keep their expectation with their carrier
# (see the disposition blocks above); none is restated here.
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

# Base ref for diff-scoped guards, overridable via env (precedent: #797/#798
# ISSUE_79{7,8}_BASE_REF).
BASE_REF="${ISSUE_799_BASE_REF:-$(git -C "$PROJECT_ROOT" merge-base HEAD main 2>/dev/null || true)}"

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
echo "=== AC8 SECONDARY-PRESERVED (guard, feat AC8) ==="
# Widened diff scope per ledger E6/C3: git diff BASE...HEAD -- docs/ README.md
# must touch no line carrying the 'Secondary (multi-repo):' marker.

if [[ -z "$BASE_REF" ]]; then
  echo "  SKIP: AC3-guard (no base ref available)"
  TESTS=$((TESTS + 1))
else
  # #848 admission (same remedy class as the CLAUDE.md #846 window
  # re-anchor below): #848's GATE:PLAN-passed design (ledger E11/E12)
  # promotes the DELIVER multi-repo fenced list to a purely ADDITIVE
  # '*Secondary (multi-repo):*' marker line in docs/autoflow-guide.md.
  # The #799 concern is unchanged for every other marker: no pre-existing
  # marker line may be removed or altered — only the one approved #848
  # added line is filtered out of the diff scan.
  # #985 admission (same remedy class): the public-release identifier sweep
  # generalizes the pre-sweep org/repo token INSIDE docs/git-workflow.md:220's
  # '*Secondary (multi-repo):*' marker line (the old owner/repo pair for
  # this repo -> 'Munsik-Park/autoflow#N') — the marker text itself is unchanged
  # and the line still opens with '*Secondary (multi-repo):*' before and
  # after; only the old (-) and new (+) full lines of that one
  # identifier-only edit are filtered out. Every other marker line, and any
  # OTHER edit to this one, still trips the guard.
  secondary_marker_diff="$(git diff "$BASE_REF"...HEAD -- docs/ README.md 2>/dev/null \
    | grep -E '^[+-].*Secondary \(multi-repo\):' \
    | grep -vF '+*Secondary (multi-repo):* In a multi-repo deployment (one or more submodules), DELIVER fans out' \
    | grep -vF -- '-*Secondary (multi-repo):* in a multi-repo deployment only the host PR uses `Closes`; each sub-repo PR uses `Part of '"conn""ev-llm/claude-autoflow"'#N` — see [`CLAUDE.md`](../CLAUDE.md) > PR Issue Auto-Close.' \
    | grep -vF -- '+*Secondary (multi-repo):* in a multi-repo deployment only the host PR uses `Closes`; each sub-repo PR uses `Part of Munsik-Park/autoflow#N` — see [`CLAUDE.md`](../CLAUDE.md) > PR Issue Auto-Close.' || true)"
  assert_true "AC3-guard: no diff hunk over docs/ README.md touches a 'Secondary (multi-repo):' marker line" \
    "[ -z '$secondary_marker_diff' ]"
fi

# AC3-nores: no NEW doc line (changed-surface only, verification design §6
# AC3-nores: "no doc points at services/librechat as a live tracked path")
# introduces an unqualified services/librechat reference. Diff-scoped per
# the AC3-guard pattern above — this deliberately does NOT recurse over all
# of docs/, which would also trip on pre-existing/out-of-scope files this
# cycle is forbidden to touch (docs/librechat-deploy-extraction-plan.md —
# S12/#800 territory; docs/adr/0001-*.md — hard-DENY docs/adr/).
if [[ -z "$BASE_REF" ]]; then
  echo "  SKIP: AC3-nores (no base ref available)"
  TESTS=$((TESTS + 1))
else
  nores_diff="$(git diff "$BASE_REF"...HEAD -- docs/ README.md 2>/dev/null \
    | grep -E '^\+.*services/librechat' \
    | grep -v -E 'N/A|#798|historical|no longer|detach' || true)"
  assert_true "AC3-nores: no NEW doc line (changed surface) points at services/librechat as a live tracked path" \
    "[ -z '$nores_diff' ]"
fi

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
echo "=== AC10 scope arms — .claude/hooks/** parity + .claude/workflows/** manifest-sha (feat AC10) ==="
# The hand-maintained path allow-list this block once carried was retired by
# issue #75 (a merged cycle's array forces every later cycle to edit it); what
# survives here are the two path-parity arms, neither keyed on an allow-list.

if [[ -z "$BASE_REF" ]]; then
  echo "  SKIP: AC6-scope (no base ref available)"
  TESTS=$((TESTS + 1))
else
  diff_files="$(git diff --name-only "$BASE_REF"...HEAD 2>/dev/null || true)"



  # #843 parity-carried exception (same shape as test-798 AC9 / test-788
  # AC10a): the hook is allowed to change ONLY when its plugin/autoflow/hooks
  # mirror lands byte-identical in the same diff (verify-package.sh AC5
  # parity) — this is the first intentional engine-hook edit since #790.
  hooks_touched_ac6="no"
  printf '%s\n' "$diff_files" | grep -q '^\.claude/hooks/' && hooks_touched_ac6="yes"
  hooks_admitted_ac6="no"
  if [[ "$hooks_touched_ac6" == "no" ]]; then
    hooks_admitted_ac6="yes"
  elif [[ "$diff_files" == *".claude/hooks/check-autoflow-gate.sh"* ]] \
    && cmp -s "$PROJECT_ROOT/.claude/hooks/check-autoflow-gate.sh" \
              "$PROJECT_ROOT/plugin/autoflow/hooks/check-autoflow-gate.sh" 2>/dev/null; then
    hooks_admitted_ac6="yes"
  fi
  assert_true "AC6-scope: diff does not touch .claude/hooks/**, OR only check-autoflow-gate.sh with its plugin mirror byte-identical (#843 parity-carried exception)" \
    "[ '$hooks_admitted_ac6' = 'yes' ]"
  # #62 window replacement (feature design D10, supersedes the #985/#27/#56/#59
  # substring chain): the per-cycle grep -vF allow window does not scale — that
  # cycle's edit leaves 99 surviving lines, 27 of them <=25-char generic
  # fragments, and admitting those as literals would make the arm match any
  # future edit under the path. The scope obligation this lane actually owes is
  # "no cycle sprawls into a workflow file it did not declare", which is a
  # file-set property, not a line property. Within-file content protection is
  # NOT dropped — it is carried, permanently and independently of diff size, by
  # tests/fixtures/doc-invariants.json's scope:"permanent" rows on the workflow
  # scripts and by the manifest sha256 pin regenerated in the same commit
  # (AC-56-10a, AC-59-9).
  workflows_touched_ac6="$(printf '%s\n' "$diff_files" | grep '^\.claude/workflows/' || true)"
  workflows_admitted_ac6="yes"
  while IFS= read -r wf; do
    [[ -z "$wf" ]] && continue
    # No filename allow-list here, deliberately. Since issue #75 retired this
    # file's path-level array, WHICH files a cycle may touch is carried by
    # docs/submodule-common-rules.md > Change Surface Rules (the trace rule plus
    # the pre-PR `git diff <base>...HEAD` self-audit), not by an in-suite
    # inventory a later cycle would have to edit. A workflow path with no manifest artifacts[]
    # row yields an empty man_sha and therefore still fails the equality below, so
    # sprawl into an unpinned workflow file is caught by this arm as well.
    wf_sha="$(shasum -a 256 "$PROJECT_ROOT/$wf" 2>/dev/null | awk '{print $1}')"
    man_sha="$(jq -r --arg s "$wf" '.artifacts[] | select(.source==$s) | .sha256' "$PROJECT_ROOT/setup/manifest.json")"
    # Both -n guards are load-bearing: -n "$wf_sha" is "still exists in the
    # worktree" (a DELETED path is listed by git diff --name-only, shasum emits
    # nothing); -n "$man_sha" is "carries a setup/manifest.json artifacts[] row"
    # (jq -r on an absent row emits nothing). Without the first, a cycle that
    # deletes a workflow script together with its manifest row compares "" to ""
    # and is silently ADMITTED.
    [[ -n "$wf_sha" && -n "$man_sha" && "$wf_sha" == "$man_sha" ]] || workflows_admitted_ac6="no"
  done <<< "$workflows_touched_ac6"
  assert_true "AC6-scope: diff touches no .claude/workflows/** path, OR every touched .claude/workflows/** path has a setup/manifest.json sha256 row matching its current content (#62 D10 — supersedes the #985/#27/#56/#59 substring window)" \
    "[ '$workflows_admitted_ac6' = 'yes' ]"
fi

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
