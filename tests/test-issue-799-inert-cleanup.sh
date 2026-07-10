#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
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
# below use the verification design's Group A-H sub-oracle ids
# (AC1-neg/pos, AC2-*, AC3-*, AC5D/G/H-*, AC6-*), bound to feature AC1-AC12
# by the §6 crosswalk table. One id set binds RED/GREEN.
#
# Scope (verification design §2 Tier-1):
#   AC1-neg/pos   README-CONSUMED-PRESENT   (feat AC1, D1)
#   AC2-neg/pos   README-LEGACY-ANNOTATION-ABSENT (feat AC2, D2)
#   AC2-tree      structure-tree spot subset (feat AC2, D2)
#   AC3D-*        README-CHECKLIST-CURRENT  (feat AC3, D3)
#   AC3-guide/common/ext  SUBMODULE-SELFREF-ABSENT + DETACH-REF-PRESENT
#                 (feat AC4/AC5, D4)
#   AC3-guard     SECONDARY-PRESERVED (guard, feat AC8)
#   AC3-nores     no doc points at the residual untracked services/ working copy
#   AC5D-index-*  INDEX-INERT-ROUTE-ABSENT (feat AC6, D5)
#   AC5D-maint-neg  maintained-docs neutralize-in-place (feat AC6, D5)
#   AC4-guard     no broken host-scoped link introduced (preservation)
#   AC5G-neg/guard  GITWORKFLOW-DEFERRAL-CLEARED (feat AC7, D6)
#   AC5H-degenerate DEGENERATE-PROSE-PRESERVED (guard, feat AC9)
#   AC5H-nosubmod   NO-SUBMODULE-REINTRO (guard, feat AC11)
#   AC6-scope     NO-FORBIDDEN-FILES / allow-list containment (feat AC10)
#   AC6-ci        CI-ENFORCED (feat AC12, D7)
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
# keystone): AC1-neg (wizard narrative present), AC1-pos (--target /
# /plugin absent), AC2-neg (template-era x2 present), AC3-guide/common/ext
# (self-claim present, no #798 qualifier), AC3D-checklist-neg/section-neg
# (legacy strings present), AC5D-index-neg (services/librechat/docs/
# present), AC5D-maint-neg (N/A qualifier absent), AC5G-neg (deferred to
# S11a present) all FAIL. AC3-guard/AC4-guard/AC5H-degenerate/AC5H-nosubmod/
# AC5G-guard are preservation guards and PASS both pre- and post-change.
# AC6-scope/AC6-ci become GREEN only once the suite + CI wiring land.
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
echo "=== AC1 README-CONSUMED-PRESENT (feat AC1, D1) ==="

assert_false "AC1-neg: README no longer narrates the interactive setup wizard as the primary path" \
  "grep -qF 'The setup wizard asks for project configuration' '$README_MD'"
# [Non-vacuity, verification §4 keystone] README has no --target occurrence
# today — this must FAIL pre-edit or the test is mis-scoped.
assert_true "AC1-pos: README documents the consumed-tool --target flow" \
  "grep -qF -- '--target' '$README_MD' && grep -qF '/plugin marketplace add' '$README_MD' && grep -qF '/plugin install' '$README_MD'"

# =============================================================================
echo ""
echo "=== AC2 README-LEGACY-ANNOTATION-ABSENT (feat AC2, D2) ==="

assert_false "AC2-neg: README no longer annotates init.sh/SETUP-GUIDE.md as template-era" \
  "grep -qF '(template-era; kept as reference)' '$README_MD'"
# AC2-tree: spot subset of currently-shipped top-level entries the structure
# tree omits pre-edit (verification §1 Group B AC2-tree automated arm).
assert_true "AC2-tree: README structure tree lists docs/adr/, docs/phases/, .claude/agents/, .claude/workflows/, .github/workflows/, scripts/, tests/, plugin/, setup/manifest.json" \
  "grep -qF 'docs/adr/' '$README_MD' && grep -qF 'docs/phases/' '$README_MD' && grep -qF '.claude/agents/' '$README_MD' && grep -qF '.claude/workflows/' '$README_MD' && grep -qF '.github/workflows/' '$README_MD' && grep -qF 'scripts/' '$README_MD' && grep -qF 'tests/' '$README_MD' && grep -qF 'plugin/' '$README_MD' && grep -qF 'setup/manifest.json' '$README_MD'"

# =============================================================================
echo ""
echo "=== AC3 README-CHECKLIST-CURRENT (feat AC3, D3) ==="
# Paired negative + positive oracles per verification DCR-3 (P2 non-vacuity):
# a negative-only oracle could pass by deleting the checklist wholesale.

assert_false "AC3D-checklist-neg: README Post-Setup no longer cites the legacy 'no remaining {{placeholders}}' output" \
  "grep -qF 'no remaining \`{{placeholders}}\`' '$README_MD'"
assert_true "AC3D-checklist-pos: README Post-Setup references drift-check.sh or AUTOFLOW-IMPORT" \
  "grep -qF 'drift-check.sh' '$README_MD' || grep -qF 'AUTOFLOW-IMPORT' '$README_MD'"
assert_false "AC3D-section-neg: README Single-Repo-vs-Multi-Repo no longer says 'skip the sub-repo placeholders'" \
  "grep -qF 'skip the sub-repo placeholders' '$README_MD'"

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
echo "=== AC6 INDEX-INERT-ROUTE-ABSENT (feat AC6, D5) ==="

assert_false "AC5D-index-neg: INDEX.md no longer routes to the inert services/librechat/docs/ path" \
  "grep -qF 'services/librechat/docs/' '$INDEX_MD'"
# AC5D-index-pos: absence guard — INDEX.md carries no services/librechat
# route at all post-neutralization (full coherence review of the replacement
# routing is Tier-2, verification §1 Group D).
assert_true "AC5D-index-pos: INDEX.md carries no route to a non-existent services/librechat path" \
  "! grep -qF 'services/librechat' '$INDEX_MD'"

# AC5D-maint-neg: finalized R2 (ledger E5) — neutralize-in-place, header
# retained, qualifier added. Discriminator verified ABSENT pre-edit.
assert_true "AC5D-maint-neg: maintained-docs.md carries the 'N/A under zero-submodule topology' qualifier" \
  "grep -qF 'N/A under zero-submodule topology' '$MAINTAINED_DOCS'"
# Paired non-vacuity: header retained (neutralize-in-place, not delete).
assert_true "AC5D-maint-neg (paired): '### Sub-repo (\`services/librechat\`)' header still present" \
  "grep -qF '### Sub-repo (\`services/librechat\`)' '$MAINTAINED_DOCS'"

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
echo "=== AC7 GITWORKFLOW-DEFERRAL-CLEARED (feat AC7, D6) ==="

assert_false "AC5G-neg: git-workflow.md no longer says 'deferred to S11a'" \
  "grep -qF 'deferred to S11a' '$GIT_WORKFLOW'"
assert_true "AC5G-guard: git-workflow.md still frames the reconcile step as 'active N/A'" \
  "grep -qF 'active N/A' '$GIT_WORKFLOW'"

# =============================================================================
echo ""
echo "=== AC9 DEGENERATE-PROSE-PRESERVED (guard, feat AC9) ==="

assert_true "AC5H-degenerate: README still contains 'single-repo is the degenerate case'" \
  "grep -qF 'single-repo is the degenerate case' '$README_MD'"

# =============================================================================
echo ""
echo "=== AC11 NO-SUBMODULE-REINTRO (guard, feat AC11) ==="

assert_false "AC5H-nosubmod: README does not reintroduce --recurse-submodules" \
  "grep -qF -- '--recurse-submodules' '$README_MD'"
assert_false "AC5H-nosubmod: README does not reintroduce '(git submodule)'" \
  "grep -qF '(git submodule)' '$README_MD'"

# =============================================================================
echo ""
echo "=== AC10 NO-FORBIDDEN-FILES / allow-list containment (feat AC10) ==="
# Allow-list = verification AC6-scope / feature §2, byte-equal (ledger E9).

if [[ -z "$BASE_REF" ]]; then
  echo "  SKIP: AC6-scope (no base ref available)"
  TESTS=$((TESTS + 1))
else
  diff_files="$(git diff --name-only "$BASE_REF"...HEAD 2>/dev/null || true)"
  allow_list=(
    # HANDOFF step 6.7 digest co-ride: every terminal cycle appends one record
    # to the durable corpus on the same PR branch (autoflow-guide.md > HANDOFF 6.7),
    # so the digest file is a standing expected surface for every cycle diff.
    "docs/cycle-digest.jsonl"
    # #973 change surface (SIGPIPE extractor-pipe fix): 10 hazard sites →
    # Safe-form across 4 suites + the #964 guard extension + the doc convention
    # + this cycle's mutual scope-guard allow-list admissions (2nd-transition
    # self/sibling registration) + manifest regen (submodule-common-rules.md source).
    "tests/test-issue-964-sigpipe-safe-pipes.sh"
    "tests/manual/issue-973-manual-scenarios.md"
    "docs/submodule-common-rules.md"
    "setup/manifest.json"
    "tests/test-issue-799-inert-cleanup.sh"
    "tests/test-issue-800-doc-assertions.sh"
    "tests/test-issue-846-doc-assertions.sh"
    "tests/test-issue-848-doc-assertions.sh"
    "tests/test-issue-798-topology-flip.sh"
    "tests/test-issue-949-manifest-regen-doc.sh"
    "tests/test-issue-952-wizard-removal.sh"
    "tests/test-issue-955-subagent-background-ban.sh"
    "README.md"
    "docs/autoflow-guide.md"
    "docs/submodule-common-rules.md"
    "docs/external-review-sequencing.md"
    "docs/INDEX.md"
    "docs/maintained-docs.md"
    "docs/git-workflow.md"
    "tests/test-issue-799-inert-cleanup.sh"
    ".github/workflows/e2e-dummy-target.yml"
    "tests/manual/issue-799-manual-scenarios.md"
    # setup/manifest.json: mechanical hash re-sync — 6 manifest-tracked docs are
    # edited by this cycle, so their sha256 entries must follow (CI AC2e; #798
    # precedent ecf8bae).
    "setup/manifest.json"
    # tests/fixtures/e2e-bundle-purity-baseline.txt: E2a ratchet-down — the
    # baseline's own contract (its header) requires removing entries this
    # cycle cleans (INDEX.md), and names S11b as a burn-down stage.
    "tests/fixtures/e2e-bundle-purity-baseline.txt"
    # #964 (SIGPIPE-safe assertion pipes): sibling cycle files — the 13-line
    # guard transform touches 798/800/949/955 in place (no filename change,
    # docs/submodule-common-rules.md already listed above), and the new RED
    # suite (cc8030d precedent).
    "tests/test-issue-798-topology-flip.sh"
    "tests/test-issue-800-doc-assertions.sh"
    "tests/test-issue-949-manifest-regen-doc.sh"
    "tests/test-issue-955-subagent-background-ban.sh"
    "tests/test-issue-964-sigpipe-safe-pipes.sh"
    # Reciprocal registration: 16ebab9 added #964 cycle files to 952's own
    # G1 allow-list, pulling the 952 suite into this cycle's diff.
    "tests/test-issue-952-wizard-removal.sh"
    # #846 sibling-fix pass: review-triage hardening RED suite lands on the
    # same branch (test/CI surface only; no #799 content touched).
    "tests/test-issue-846-doc-assertions.sh"
    "tests/manual/issue-846-manual-scenarios.md"
    # #846 sibling-fix pass, transitive: the other scope-guard tests' own
    # allow-lists were amended (this same pass) to re-admit the two #846
    # files above — those edits land in this diff too.
    "tests/test-issue-798-topology-flip.sh"
    "tests/test-issue-800-doc-assertions.sh"
    "tests/test-issue-949-manifest-regen-doc.sh"
    "tests/test-issue-952-wizard-removal.sh"
    # #848 transitive: sibling guard-admission edits (b8b9ad6) land on this branch
    "tests/test-issue-794-doc-assertions.sh"
    "tests/test-issue-795-handoff-removal.sh"
    "tests/test-issue-955-subagent-background-ban.sh"
    # #846 GREEN source surface (GATE:PLAN-passed design §2, commit f5d5539):
    # review-triage hardening edits these docs (and one CLAUDE.md Regressions
    # clause, design §2.4) on the same branch; docs/autoflow-guide.md and
    # setup/manifest.json are already admitted above. The CLAUDE.md negative
    # arm below is re-anchored to a content window instead of a blanket ban.
    ".codex/review.md"
    "docs/design-rationale.md"
    "CLAUDE.md"
    # #848 sibling-fix pass: the pointer-bump procedure + propagation-batching
    # RED suite + manual scenarios land on the same branch; its GREEN source
    # docs (autoflow-guide.md / git-workflow.md / external-review-sequencing.md
    # / submodule-common-rules.md / CLAUDE.md) are already admitted above.
    "tests/test-issue-848-doc-assertions.sh"
    "tests/manual/issue-848-manual-scenarios.md"
    # #843 cycle files (concurrent-cycle registration, cc8030d precedent):
    ".claude/hooks/check-autoflow-gate.sh"
    "plugin/autoflow/hooks/check-autoflow-gate.sh"
    "docs/phases/analysis.md"
    "docs/evaluation-system.md"
    "tests/test-issue-223-schema-hook-contract.sh"
    "tests/test-issue-245-schema-validation.sh"
    "tests/test-issue-843-doc-assertions.sh"
    "tests/test-issue-844-doc-assertions.sh"
    # #844 cycle files (concurrent-cycle registration, cc8030d precedent).
    "docs/teammate-common-rules.md"
    "tests/manual/issue-844-manual-scenarios.md"
    # #844 INTEGRATE reconciliation pass: sibling line-window re-anchor +
    # allow-list registration touches this test file on the same branch.
    "tests/test-issue-794-doc-assertions.sh"
    # #843 RED-pass test-contract updates to the sibling guard suites the same
    # commit touches (test-952 G1 registers the identical full set, 54/54).
    "tests/plugin/verify-package.sh"
    "tests/test-issue-788-host-purity-delta.sh"
    "tests/test-issue-798-topology-flip.sh"
    "tests/test-issue-800-doc-assertions.sh"
    "tests/test-issue-952-wizard-removal.sh"
    "tests/test-issue-955-subagent-background-ban.sh"
    # #951 (doc-invariant registry): sibling cycle files — the new registry
    # runner, hermetic base-ref resolver, registry data, lifecycle-rule doc,
    # RED suite + fixtures land on the same branch (docs/INDEX.md and
    # docs/maintained-docs.md already admitted above, df4641d/da11389/fa12eb1
    # precedent). #951 also DELETES tests/test-issue-796-doc-assertions.sh
    # and tests/test-issue-797-doc-invocation.sh (794/800/949 already
    # admitted above); their permanent invariants migrate into the registry.
    "tests/test-issue-796-doc-assertions.sh"
    "tests/test-issue-797-doc-invocation.sh"
    "tests/test-issue-951-registry.sh"
    # Round-2 fix (VERIFY): omitted from round-1 registration above.
    "tests/adr-0016-conformance-check.sh"
    "tests/test-issue-795-handoff-removal.sh"
    "tests/fixtures/doc-invariants-anchor-fixture.md"
    "tests/fixtures/doc-invariants-baseline.txt"
    "tests/fixtures/doc-invariants-dialect-fixture.md"
    "tests/manual/issue-951-manual-scenarios.md"
    "tests/run-doc-invariants.sh"
    "tests/lib/base-ref.sh"
    "tests/lib/"
    "tests/fixtures/doc-invariants.json"
    "docs/doc-invariant-registry.md"
    # #954 cycle files (cross-issue complaint-class recurrence scan RED
    # suite + fixtures + manual scenarios) and this cycle's own
    # allow-list-registration churn on the sibling scope-guard suites
    # (self-referential, #844/#846 precedent).
    "tests/test-issue-954-cross-issue-scan.sh"
    "tests/fixtures/cycle-digest-954-below-k.jsonl"
    "tests/fixtures/cycle-digest-954-at-k.jsonl"
    "tests/fixtures/cycle-digest-954-dedup.jsonl"
    "tests/fixtures/cycle-digest-954-out-of-window.jsonl"
    "tests/fixtures/cycle-digest-954-dual-axis.jsonl"
    "tests/fixtures/cycle-digest-954-cross-axis.jsonl"
    "tests/fixtures/cycle-digest-954-dedup-window.jsonl"
    "tests/manual/issue-954-manual-scenarios.md"
    # #954 INTEGRATE reconciliation: the 953 suite's AC5-whitelist-analysis
    # grep is narrowed to the whitelist block (the #954 AC7 non-conflation
    # paragraph legitimately names cycle-digest), so the 953 suite file
    # lands in this cycle's diff.
    "tests/test-issue-953-cycle-digest.sh"
    # #954 GREEN source surface (GATE:PLAN-passed design §4, commit
    # b26cda9): PREFLIGHT step-1.5 scan step + tally script + backlog
    # intake path + maintained-docs trigger + analyzer variant + doc-sync
    # + manifest regen land on the same branch (#953/#844 precedent).
    ".claude/agents/autoflow-analyzer.md"
    "docs/improvement-backlog.md"
    "plugin/autoflow/agents/autoflow-analyzer.md"
    "scripts/preflight/scan-cross-issue-recurrence.sh"
    # #978 cycle files (concurrent-cycle registration, cc8030d precedent):
    # archive-semantics GREEN rewrites the cleanup wrapper in place and the
    # RED pass re-targets the boundary guard + adds the repo-key guard
    # (CLAUDE.md / docs / setup/manifest.json / doc-invariants.json /
    # test-issue-844 / e2e workflow already admitted above).
    "scripts/cleanup/cleanup-issue.sh"
    "scripts/test/check-cleanup-issue-boundary.sh"
    "scripts/test/check-repo-key.sh"
    # #985 cycle files (public-tree sanitization sweep): REUSE/SPDX
    # licensing, identifier generalization, internal-doc removal across the
    # full repo surface (same set as test-issue-952-wizard-removal.sh's own
    # #985 registration; CLAUDE.md / docs/INDEX.md / docs/maintained-docs.md
    # / setup/manifest.json / docs/improvement-backlog.md already admitted
    # above).
    ".claude-plugin/marketplace.json"
    ".claude/hooks/check-read-dedup.sh"
    ".claude/skills/epic-dash/SKILL.md"
    ".claude/skills/epic-dash/scripts/build_pipeline.py"
    ".claude/skills/epic-dash/scripts/extract_deps.py"
    ".claude/skills/epic-dash/scripts/fetch.sh"
    ".claude/skills/epic-dash/scripts/render_dash.py"
    ".claude/workflows/architect-deliberation.js"
    ".claude/workflows/verify-cause-branch.js"
    ".github/pull_request_template.md"
    ".github/workflows/host-purity-delta.yml"
    ".github/workflows/plugin-package.yml"
    ".github/workflows/reuse.yml"
    ".github/workflows/schema-hook-contract.yml"
    ".github/workflows/workflow-regression.yml"
    "Jenkinsfile"
    "LICENSE"
    "LICENSES/Elastic-2.0.txt"
    "REUSE.toml"
    '"docs/LibreChat_\355\224\204\353\241\234\354\240\235\355\212\270\354\225\210.docx"'
    "docs/adr/0001-host-orchestrator-and-librechat-submodule-""boundary.md"
    "docs/adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md"
    "docs/adr/README.md"
    "docs/gate-matching-standard.md"
    "docs/host-service-decoupling-plan.md"
    "docs/librechat-deploy-extraction-plan.md"
    "docs/repo-boundary-rules.md"
    "docs/reviewer-backend.md"
    "docs/security-checklist.md"
    "plugin/autoflow/.claude-plugin/plugin.json"
    "plugin/autoflow/README.md"
    "plugin/autoflow/hooks/check-read-dedup.sh"
    "plugin/autoflow/skills/epic-dash/SKILL.md"
    "plugin/autoflow/skills/epic-dash/scripts/build_pipeline.py"
    "plugin/autoflow/skills/epic-dash/scripts/extract_deps.py"
    "plugin/autoflow/skills/epic-dash/scripts/fetch.sh"
    "plugin/autoflow/skills/epic-dash/scripts/render_dash.py"
    "plugin/autoflow/skills/install/SKILL.md"
    "plugin/autoflow/skills/install/scripts/detect.sh"
    "plugin/autoflow/skills/install/scripts/scaffold-identity.sh"
    "plugin/autoflow/skills/install/scripts/set-review-backend.sh"
    "scripts/handoff/create-host-pr.sh"
    "scripts/handoff/emit-cycle-digest.sh"
    "scripts/preflight/check-review-backend.sh"
    "scripts/resync-submodules.sh"
    "scripts/review/codex-review-pr.sh"
    "scripts/review/lib/claude-isolation.sh"
    "scripts/test/check-close-keyword-quoting.sh"
    "scripts/test/check-host-purity-delta.sh"
    "scripts/test/check-maintained-docs-sync.sh"
    "setup/SETUP-GUIDE.md"
    "setup/gen-manifest-hashes.sh"
    "setup/init.sh"
    "setup/thin-root-layer/drift-check.sh"
    "setup/thin-root-layer/settings-pin.json"
    "test/workflows/run.mjs"
    "tests/fixtures/expected-conn""ev-residual.txt"
    "tests/issue-92/manual-checklist.md"
    "tests/issue-92/test-boundary-nonviolation.bats"
    "tests/issue-92/test-create-host-pr.bats"
    "tests/issue-92/test-cross-file-consistency.bats"
    "tests/issue-92/test-docs.bats"
    "tests/issue-92/test-pr-template.bats"
    "tests/manual/issue-800-manual-scenarios.md"
    "tests/manual/issue-985-manual-scenarios.md"
    "tests/plugin/manual-scenarios-797.md"
    "tests/plugin/manual-scenarios-943.md"
    "tests/plugin/manual-scenarios.md"
    "tests/plugin/verify-e2e-dummy-target.sh"
    "tests/plugin/verify-install-into-target.sh"
    "tests/plugin/verify-install-skill-scripts.sh"
    "tests/plugin/verify-thin-root-layer.sh"
    "tests/test-codex-review-label-step.sh"
    "tests/test-gate-hardening.sh"
    "tests/test-issue-847-doc-assertions.sh"
    "tests/test-issue-961-cap6-gate.sh"
    "tests/test-issue-979-bundle-delivery.sh"
    "tests/test-issue-979-doc-neutrality.sh"
    "tests/test-issue-979-preflight-backend-check.sh"
    "tests/test-issue-979-probe.sh"
    "tests/test-issue-979-review-backend.sh"
    "tests/test-issue-985-doc-assertions.sh"
  )
  disallowed=""
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    found=0
    for allowed in "${allow_list[@]}"; do
      [[ "$f" == "$allowed" ]] && found=1 && break
    done
    if [[ $found -eq 0 ]]; then
      disallowed="$disallowed$f"$'\n'
    fi
  done <<< "$diff_files"

  echo "  changed files: $(printf '%s' "$diff_files" | grep -c . || true)"
  if [[ -n "$disallowed" ]]; then
    echo "  disallowed:"
    printf '%s' "$disallowed" | sed 's/^/    /'
  fi
  assert_true "AC6-scope: git diff --name-only ⊆ allow-list (no disallowed files)" \
    "[ -z '$disallowed' ]"

  # Explicit forbidden-file negative arm (feature §2 'Not touched' hard
  # constraints / §5 dependency guards).
  # Re-anchored for #846 (same remedy class as the #794 window re-anchors,
  # precedents 2a0dae3 / 3396d7f): #846's GATE:PLAN-passed design §2.4
  # legitimately amends ONE CLAUDE.md clause — the Regressions-line cap
  # sentence ('Codex review auto-resolution (Medium+ found at HANDOFF)').
  # The #799 concern is unchanged: no OTHER CLAUDE.md content may change on
  # this branch. So instead of a blanket file ban, assert every changed
  # content line (+/-) in CLAUDE.md's diff belongs to that one sentence.
  # #848 window extension (same remedy class as the #846 re-anchor above):
  # #848's GATE:PLAN-passed design (ledger E11/E12) adds ONE approved
  # CLAUDE.md line — the Commit Ownership 'Submodule pointer bump' row
  # (committer = Orchestrator). Every other CLAUDE.md content change on
  # this branch remains forbidden.
  # #844 amends two more CLAUDE.md clauses (feature design §2: Regressions
  # cap-semantics wording clarified, GATE:PLAN's own Human-escalation
  # example folded into the per-gate cap read, and the PR Wait Rule's
  # requested-issue mode line gains a Resume-procedure cross-reference).
  # Same remedy as the #846 carve-out above: admit the specific edited
  # clauses by a substring common to BOTH the old and new line (not the
  # whole line, so any *other* future edit to these sentences still trips
  # the guard).
  # #978 amends two more CLAUDE.md clauses (AutoFlow State Tracking,
  # delete->archive rewrite): the ledger-companion sentence ("deleted with
  # it" -> "archived with it (moved to the external store)") and the
  # Completion sentence ("deletes" -> "archives ... $AUTOFLOW_ARCHIVE_ROOT").
  # Same carve-out shape — substrings common to both the old and new lines.
  # #985 amends five more CLAUDE.md lines (public-release identifier
  # generalization sweep, ledger Q1): the {{GITHUB_ORG}} placeholder example
  # org (the pre-sweep ontology-platform org example -> `my-service-org`),
  # the GATE:PLAN and GATE:QUALITY revert-rule evidence citations (the
  # pre-sweep owner/repo pair -> `Munsik-Park/autoflow#N` / bare `LibreChat
  # #268`), the sub-repo PR close-keyword example (`Part of` the pre-sweep
  # owner/repo pair `#N` -> `Part of Munsik-Park/autoflow#N`), and the Backlog
  # tracker-placement paragraph
  # (folds the removed Forward-routing paragraph's org identifiers into one
  # generalized sentence). Same carve-out shape as the #844/#978 entries
  # above — substrings common to both old and new lines where a line is
  # edited in place, full literal old+new lines where a line is
  # replaced/removed outright — so any *other* future edit to these
  # sentences still trips the guard.
  claude_md_offwindow_changes() {
    git diff "$BASE_REF"...HEAD -- CLAUDE.md 2>/dev/null \
      | grep -E '^[+-]' \
      | grep -vE '^(\+\+\+|---)' \
      | grep -vF 'Codex review auto-resolution (Medium+ found at HANDOFF)' \
      | grep -vF 'Submodule pointer bump (`services` gitlink)' \
      | grep -vF 'VERIFY deadlock unresolved by Evaluation AI arbitration → human. HANDOFF internal retry exhausted → human.' \
      | grep -vF 'read its own state file to choose the mode: `active:true` → resume the in-progress cycle' \
      | grep -vF 'retained alongside the state file and' \
      | grep -vF 'Once the PR is observed merged or closed, prior-cycle resolution' \
      | grep -vF 'etc. are written as `{{REPO_*}}`/`{{GITHUB_ORG}}` placeholders in the methodology docs' \
      | grep -vF 'GATE:PLAN | `opus` | rubric, 5 items × 10 points — reverted from `sonnet`' \
      | grep -vF 'GATE:QUALITY | `opus` | rubric, 10 items × 10 points — reverted from `sonnet`' \
      | grep -vF -- '-Part of '"conn""ev-llm/claude-autoflow"'#N' \
      | grep -vF -- '+Part of Munsik-Park/autoflow#N' \
      | grep -vF 'Tracker placement follows each repo'"'"'s composition (D4, settled in S12 #800): AutoFlow-framework work items are filed in this host repository (`' \
      | grep -vF -- '-- **Forward routing (post-#785 inversion).**'
  }
  assert_false "AC6-scope: CLAUDE.md diff confined to the #846 Regressions cap clause (no other CLAUDE.md content change)" \
    "ctx=\$(claude_md_offwindow_changes); printf '%s\n' \"\$ctx\" | grep -q ."

  # #985 parity-carried exception (same shape as the .claude/hooks/**
  # exception below): docs/adr/** is allowed to change ONLY for the exact
  # #985 public-release sweep surface — 0001's deletion (its own removed-doc
  # AC, test-issue-985-doc-assertions.sh AC1-INTERNAL-DOCS-ABSENT), the
  # matching README.md row removal, and 0015's wording-only rewording of its
  # three `docs/host-service-decoupling-plan.md` references (that doc is
  # itself deleted by #985) to a non-path prose phrase. Every other
  # docs/adr/** touch, or any OTHER content change to 0015/README.md, still
  # trips the guard.
  adr_touched_files="$(printf '%s\n' "$diff_files" | grep '^docs/adr/' || true)"
  adr_admitted_ac6="yes"
  while IFS= read -r adr_f; do
    [[ -z "$adr_f" ]] && continue
    case "$adr_f" in
      "docs/adr/0001-host-orchestrator-and-librechat-submodule-""boundary.md")
        continue ;;
      "docs/adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md")
        adr_0015_offwindow="$(git diff "$BASE_REF"...HEAD -- "$PROJECT_ROOT/$adr_f" 2>/dev/null \
          | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' \
          | grep -vF 'refining the KEEP/TEMPLATIZE classification' \
          | grep -vF 'host/service decoupling plan' \
          | grep -vF 'as originally written): keeps the' \
          | grep -vF 'Boundary reference:' \
          | grep -vF -- '-`docs/host-service-decoupling-plan.md` §6/§10 (with that plan'"'"'s' \
          | grep -vF -- '-  (`docs/host-service-decoupling-plan.md` as originally written): keeps the' || true)"
        [[ -n "$adr_0015_offwindow" ]] && adr_admitted_ac6="no"
        ;;
      "docs/adr/README.md")
        adr_readme_offwindow="$(git diff "$BASE_REF"...HEAD -- "$PROJECT_ROOT/$adr_f" 2>/dev/null \
          | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' \
          | grep -vF '0001-host-orchestrator-and-librechat-submodule-'"boundary.md" || true)"
        [[ -n "$adr_readme_offwindow" ]] && adr_admitted_ac6="no"
        ;;
      *)
        adr_admitted_ac6="no" ;;
    esac
  done <<< "$adr_touched_files"
  assert_true "AC6-scope: diff does not touch docs/adr/**, OR only the #985 0001-deletion + README row-removal + 0015 host-service-decoupling-plan.md-rewording surface (ledger Q1)" \
    "[ '$adr_admitted_ac6' = 'yes' ]"

  # #985 parity-carried exception: docs/repo-boundary-rules.md changes ONLY
  # the identifier-generalization Backlog paragraph (drops the pre-sweep
  # service-host forward-routing sentence and the pre-sweep owner/repo
  # token, folding into one generalized sentence) — same
  # substring-common-to-both-lines carve-out shape as the CLAUDE.md window
  # above. Any OTHER content change still trips the guard.
  repo_boundary_offwindow="$(git diff "$BASE_REF"...HEAD -- docs/repo-boundary-rules.md 2>/dev/null \
    | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' | grep -vE '^[+-]$' \
    | grep -vF 'Tracker placement follows each repo'"'"'s composition (D4, settled in S12 #800): AutoFlow-framework tracking items' \
    | grep -vF -- '-**Forward-routing rule (post-#785 inversion).**' \
    | grep -vF -- '-> **Transition note (epic #785):**' \
    | grep -vF -- '+> **Transition note (epic #785):**' \
    | grep -vF -- '-> service host `'"conn""ev-llm/llmroute"'` while AutoFlow-framework issues stay in `'"conn""ev-llm/claude-autoflow"'` — was' \
    | grep -vF -- '+> to this host repository (`Munsik-Park/autoflow`) — was' \
    | grep -vF 'executed in S12 (#800), following the S11a (#798) host↔target flip' \
    | grep -vF 'S12 go/no-go migration manifest' || true)"
  assert_true "AC6-scope: diff does not touch docs/repo-boundary-rules.md, OR only the #985 Backlog forward-routing identifier-generalization paragraph (ledger Q1)" \
    "[ -z '$repo_boundary_offwindow' ]"
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
  # #985 parity-carried exception: .claude/workflows/** is allowed to change
  # ONLY for the SPDX header the REUSE-lint sweep prepends to every
  # header-bearing tracked source (test-issue-985-doc-assertions.sh
  # AC3-SPDX-COVERAGE) — a pure two-line addition, no content-line change.
  # Any OTHER content change under .claude/workflows/** still trips the
  # guard.
  workflows_touched_ac6="$(printf '%s\n' "$diff_files" | grep '^\.claude/workflows/' || true)"
  workflows_admitted_ac6="yes"
  while IFS= read -r wf; do
    [[ -z "$wf" ]] && continue
    # REUSE-IgnoreStart
    wf_offwindow="$(git diff "$BASE_REF"...HEAD -- "$wf" 2>/dev/null \
      | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' \
      | grep -vF '+// SPDX-FileCopyrightText: 2026 Munsik-Park' \
      | grep -vF '+// SPDX-License-Identifier: Elastic-2.0' || true)"
    # REUSE-IgnoreEnd
    [[ -n "$wf_offwindow" ]] && workflows_admitted_ac6="no"
  done <<< "$workflows_touched_ac6"
  assert_true "AC6-scope: diff does not touch .claude/workflows/**, OR only the #985 SPDX-header two-line addition (ledger Q1)" \
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
