#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: docs/doc-invariant-registry.md .github/workflows/contract-suites.yml tests/test-run-doc-invariants.sh
# =============================================================================
# Test: cycle-scoped disposition-record suite — Issue #85 AC-disposition-record
# =============================================================================
# .autoflow/issue-85-verification-design.md > AC-disposition-record:
#   each #76 test artefact's disposition is recorded in the registry's
#   issue-#85 provenance section and executed (retire / fold-in / rename),
#   zero bare deletions, and no retired path survives in a carrier inventory.
#   Assert row<->tree agreement (retired => path absent; fold-in => source
#   absent and the named destination carries the assertion; renamed => old
#   path absent, new path present and CI-registered); assert no artefact
#   vanished from the tree without a row; and assert retirement closure — for
#   each retired path, `git grep -F <path>` over the tree matches only the two
#   files that must name it: the disposition record
#   (docs/doc-invariant-registry.md) and this suite's own row inventory.
#
# This suite's own row inventory (RETIRED_ASSETS / RENAMES below) is the
# hard-coded asset list this cycle's feature design (.autoflow/issue-85-
# feature-design.md > 2, > 3.1) fixes for the #76 artifacts. It is not
# re-derived from the registry text, because the registry's §7 disposition
# rows are prose (the §6 precedent this cycle's §7 follows), not a
# machine-parseable schema — this suite is itself half of "this cycle's row
# inventory" the retirement-closure assertion names as one of the two
# expected referrers.
#
# CYCLE-SCOPED (docs/doc-invariant-registry.md §1/§2 — depends on this
# cycle's own landed state, not a tree-permanent STATE property): this suite,
# its `run:` step and its `paths:` entry are removed together in the cycle's
# final commit before the DELIVER push, with its own disposition row recorded
# in §7 (docs/autoflow-guide.md > RED — Test Writing (Test First) > Naming).
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0; FAIL=0; TESTS=0

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

echo "=== Issue #85 AC-disposition-record — #76 test-asset disposition (cycle-scoped) ==="

REGISTRY="$PROJECT_ROOT/docs/doc-invariant-registry.md"
WORKFLOW="$PROJECT_ROOT/.github/workflows/contract-suites.yml"
FOLDIN_DEST="$PROJECT_ROOT/tests/test-run-doc-invariants.sh"
SELF_REL="tests/test-issue-85-disposition-record.sh"

# ---------------------------------------------------------------------------
# This cycle's own row inventory (feature design §2 / §3.1).
# ---------------------------------------------------------------------------

# retired — bare-deletion class (no destination carries the assertion)
RETIRED_ASSETS=(
  "tests/test-issue-76-migration-map-total.sh"
  "tests/lib/issue-76-extract-assertions.sh"
  "tests/fixtures/issue-76-migration-map.md"
  "tests/test-issue-76-manual-doc-retirement.sh"
  "tests/manual/issue-76-manual-scenarios.md"
)

# fold-in — source retired, destination carries the assertion
FOLDIN_SOURCE="tests/test-issue-76-runner-self-test-contract.sh"

# renamed — old path absent, new path present and CI-registered
RENAME_OLD=(
  "tests/test-issue-76-orphan-registration.sh"
  "tests/test-issue-76-standing-lints.sh"
  "tests/fixtures/issue-76-anchor-valid-line-registry.json"
  "tests/fixtures/issue-76-anchor-multi-match-registry.json"
  "tests/fixtures/issue-76-anchor-zero-match-registry.json"
  "tests/fixtures/issue-76-anchor-block-thematic-break-registry.json"
  "tests/fixtures/issue-76-anchor-block-explicit-end-registry.json"
  "tests/fixtures/issue-76-anchor-fixture-doc.md"
)
RENAME_NEW=(
  "tests/test-workflow-trigger-conformance.sh"
  "tests/test-standing-lint-drives.sh"
  "tests/fixtures/anchor-resolution-valid-line-registry.json"
  "tests/fixtures/anchor-resolution-multi-match-registry.json"
  "tests/fixtures/anchor-resolution-zero-match-registry.json"
  "tests/fixtures/anchor-resolution-block-thematic-break-registry.json"
  "tests/fixtures/anchor-resolution-block-explicit-end-registry.json"
  "tests/fixtures/anchor-resolution-fixture-doc.md"
)

# ---------------------------------------------------------------------------
echo ""
echo "=== §7 provenance section exists in the registry ==="

SECTION_COUNT="$(grep -cF '## 7. Migration provenance — retired-guard dispositions (issue #85)' "$REGISTRY" 2>/dev/null || true)"
assert_true "docs/doc-invariant-registry.md carries the §7 issue-85 provenance heading exactly once (got: ${SECTION_COUNT:-0})" \
  "[ \"${SECTION_COUNT:-0}\" -eq 1 ]"

# ---------------------------------------------------------------------------
echo ""
echo "=== row<->tree agreement: retired (bare-deletion class) ==="

for asset in "${RETIRED_ASSETS[@]}"; do
  assert_true "retired: $asset is absent from the tree" \
    "[ ! -e '$PROJECT_ROOT/$asset' ]"
done

# ---------------------------------------------------------------------------
echo ""
echo "=== row<->tree agreement: fold-in ==="

assert_true "fold-in: source $FOLDIN_SOURCE is absent from the tree" \
  "[ ! -e '$PROJECT_ROOT/$FOLDIN_SOURCE' ]"
assert_true "fold-in: destination tests/test-run-doc-invariants.sh carries the runner --self-test contract leg (AC-a-3)" \
  "[ -f '$FOLDIN_DEST' ] && grep -qF 'AC-a-3' '$FOLDIN_DEST'"
assert_true "fold-in: destination tests/test-run-doc-invariants.sh carries the anchor negative-coverage leg (AC-f)" \
  "[ -f '$FOLDIN_DEST' ] && grep -qF 'AC-f' '$FOLDIN_DEST'"

# ---------------------------------------------------------------------------
echo ""
echo "=== row<->tree agreement: renamed (old absent, new present, CI-registered) ==="

for i in "${!RENAME_OLD[@]}"; do
  old="${RENAME_OLD[$i]}"
  new="${RENAME_NEW[$i]}"
  assert_true "renamed: old path $old is absent from the tree" \
    "[ ! -e '$PROJECT_ROOT/$old' ]"
  assert_true "renamed: new path $new is present in the tree" \
    "[ -e '$PROJECT_ROOT/$new' ]"
done

# CI registration applies to the two renamed suite files (their own run:
# step). The renamed fixtures are covered by the existing tests/fixtures/**
# paths: glob in the hosting workflow (feature design §3.3) so no per-fixture
# run: step is expected.
for suite_new in "tests/test-workflow-trigger-conformance.sh" "tests/test-standing-lint-drives.sh"; do
  assert_true "CI-registered: $suite_new has its own run: step in .github/workflows/contract-suites.yml" \
    "grep -qF \"run: bash $suite_new\" '$WORKFLOW'"
done

# ---------------------------------------------------------------------------
echo ""
echo "=== completeness: no #76 tests/ artefact vanished from the tree without a row (fence) ==="
# Fence, not a RED discriminator: at RED time nothing has been deleted yet, so
# this is naturally green until GREEN lands a deletion outside this suite's
# own row inventory. Uses the same base-ref resolver the sibling standing
# suite (tests/test-push-context-base-ref.sh) documents; base-unresolvable is
# reported, not silently skipped.
BASE_LIB="$PROJECT_ROOT/tests/lib/base-ref.sh"
if [ -f "$BASE_LIB" ]; then
  # shellcheck disable=SC1090
  source "$BASE_LIB"
  BASE_REF="$(cd "$PROJECT_ROOT" && resolve_base_ref 2>/dev/null || true)"
else
  BASE_REF=""
fi

if [ -n "$BASE_REF" ]; then
  DELETED="$(cd "$PROJECT_ROOT" && git diff --name-only --diff-filter=D "$BASE_REF"...HEAD -- tests/ 2>/dev/null || true)"
  KNOWN_ROW_PATHS="$(printf '%s\n' "${RETIRED_ASSETS[@]}" "$FOLDIN_SOURCE" "${RENAME_OLD[@]}")"
  UNACCOUNTED="$(comm -23 <(printf '%s\n' "$DELETED" | sort -u) <(printf '%s\n' "$KNOWN_ROW_PATHS" | sort -u))"
  assert_true "no tests/ path this cycle deletes is missing from the disposition row inventory (unaccounted: $(printf '%s' "$UNACCOUNTED" | paste -sd, -))" \
    "[ -z \"\$(printf '%s' '$UNACCOUNTED')\" ]"
else
  echo "  BLOCK: no comparison base resolvable — completeness check counted FAIL, never skipped"
  TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
echo ""
echo "=== retirement closure: no retired/renamed-away path survives in a carrier inventory ==="
# Plain recursive grep, not `git grep` — this suite is itself part of the
# expected hit set (its own row inventory literal below) and may not yet be
# tracked/staged when this runs, which `git grep` would silently miss.
# `.git/` is excluded (index/pack internals coincidentally contain path
# strings — not a carrier). `.autoflow/` is excluded — it is gitignored
# scratch (CLAUDE.md > AutoFlow State Tracking) that legitimately keeps
# retired-path names as historical planning record forever; it is not a
# pathspec exclusion, exemption array, workflow paths: line, or rationale
# comment inside a live suite/workflow, which is what this AC's closure
# assertion is about. Filtered post-hoc (not via grep's --exclude-dir) since
# this host's grep (ugrep) warns/exits non-zero on --exclude-dir given a
# directory name it does not resolve relative to cwd.

CLOSURE_PATHS=(
  "${RETIRED_ASSETS[@]}"
  "$FOLDIN_SOURCE"
  "${RENAME_OLD[@]}"
)

for p in "${CLOSURE_PATHS[@]}"; do
  HITS="$(cd "$PROJECT_ROOT" && grep -rlF -- "$p" . 2>/dev/null \
    | sed 's#^\./##' | grep -vE '^(\.git/|\.autoflow/)' | sort -u)"
  UNEXPECTED="$(comm -23 <(printf '%s\n' "$HITS") <(printf '%s\n' "docs/doc-invariant-registry.md" "$SELF_REL" | sort -u))"
  assert_true "retirement closure: $p is named only by the registry and this suite's own row inventory (unexpected: $(printf '%s' "$UNEXPECTED" | paste -sd, -))" \
    "[ -z \"\$(printf '%s' '$UNEXPECTED')\" ]"
done

# =============================================================================
echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
