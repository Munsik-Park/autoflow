#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/test/check-suite-ci-coverage.sh .github/workflows/e2e-dummy-target.yml .github/workflows/contract-suites.yml
# =============================================================================
# Test: orphan-suite registration effectiveness — Issue #76 AC-b-2/AC-b-3,
#       trigger-window preservation (AC-c-2), dangling-reference sweep
# =============================================================================
# .autoflow/issue-76-verification-design.md:
#   AC-b-2 — each named orphan suite executes on an edit to its OWN subject:
#     registration-effectiveness oracle asserting the hosting workflow's
#     `paths:` blocks cover every path in the suite's `# ci-subject:` header,
#     plus the suite file itself (`contract-suite-workflow` >
#     "Per-suite subject declaration").
#   AC-b-3 — no valid suite is left with zero execution paths:
#     `scripts/test/check-suite-ci-coverage.sh` over the real tree, exit 0,
#     plus two named --self-test legs (closure, exclusion) over a hermetic
#     fixture tree so the live-tree exit 0 is never read as vacuous.
#   AC-c-2 — the scenario-document retirement move evicts no existing
#     `paths:` entry from the fixed-window `e2e-dummy-target.yml` reads
#     (`window-safety`, `yml-window-eviction`).
#   `deleted-suite-still-read` (verification design depth table) — no
#     retained suite reads a deletion target's file TEXT (content grep, not a
#     comment mention).
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CI_WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"
COVERAGE_LINT="$PROJECT_ROOT/scripts/test/check-suite-ci-coverage.sh"

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

echo "=== Issue #76 — orphan registration, coverage lint, window & dangling-ref (AC-b-2/AC-b-3/AC-c-2) ==="

# ---------------------------------------------------------------------------
# AC-b-2 — registration-effectiveness oracle over every registered suite's
# `# ci-subject:` header. This runs against WHATEVER suites carry the header
# in the tree at test time — the oracle logic, not a hardcoded name list, so
# it is equally valid before and after GREEN adds the header lines. Absence
# of any `# ci-subject:` header anywhere (today's state) is itself reported
# as a finding, not silently skipped.
# ---------------------------------------------------------------------------
mapfile -t CI_SUBJECT_SUITES < <(grep -rl '^# ci-subject:' "$PROJECT_ROOT/tests" 2>/dev/null | sort)

assert_true "AC-b-2 pre: at least one suite declares a # ci-subject: header (none yet — orphan registration not landed)" \
  "[ \${#CI_SUBJECT_SUITES[@]} -gt 0 ]"

# All `paths:` list entries across every workflow, collected once. A GitHub
# Actions `paths:` entry ending in `/` is a directory prefix — it covers
# every file under it, not only a byte-identical hit — so coverage is
# prefix matching, not the literal-substring grep this leg used before
# RED2 (which false-failed on tests/fixtures/issue-76-anchor-fixture-doc.md
# against the declared 'tests/fixtures/' directory entry).
mapfile -t ALL_WF_PATHS < <(grep -hoE "^[[:space:]]*- ['\"][^'\"]+['\"]" "$PROJECT_ROOT"/.github/workflows/*.yml 2>/dev/null | sed -E "s/^[[:space:]]*- ['\"]//; s/['\"]\$//" | sort -u)

path_covered() {
  local path="$1" entry
  for entry in "${ALL_WF_PATHS[@]}"; do
    if [ "$entry" = "$path" ]; then
      return 0
    fi
    case "$entry" in
      */) [[ "$path" == "$entry"* ]] && return 0 ;;
    esac
  done
  return 1
}

for suite in "${CI_SUBJECT_SUITES[@]}"; do
  rel="${suite#"$PROJECT_ROOT"/}"
  subjects_line="$(grep -m1 '^# ci-subject:' "$suite")"
  subjects="${subjects_line#\# ci-subject:}"
  all_covered=true
  for path in $subjects "$rel"; do
    if path_covered "$path"; then
      covered=true
    else
      covered=false
    fi
    [ "$covered" = true ] || all_covered=false
  done
  assert_true "AC-b-2: $rel — every declared ci-subject path (and the suite itself) is covered by some workflow's paths: block" "$all_covered"
done

# ---------------------------------------------------------------------------
# AC-b-3 — standing coverage lint: existence, exit 0 over the real tree, and
# the two --self-test legs (closure over a hermetic unreachable-suite
# fixture; exclusion asserted positively for each of the three named paths).
# ---------------------------------------------------------------------------
assert_true "AC-b-3: scripts/test/check-suite-ci-coverage.sh exists" \
  "[ -x '$COVERAGE_LINT' ] || [ -f '$COVERAGE_LINT' ]"

assert_true "AC-b-3: check-suite-ci-coverage.sh exits 0 over the real tree" \
  "bash '$COVERAGE_LINT' >/tmp/issue76-coverage-lint.out 2>&1"

assert_true "AC-b-3: check-suite-ci-coverage.sh --self-test exits 0 (closure + exclusion legs both pass)" \
  "bash '$COVERAGE_LINT' --self-test >/tmp/issue76-coverage-lint-selftest.out 2>&1"

assert_true "AC-b-3: --self-test output names the closure leg (a known-unreachable fixture suite is caught)" \
  "grep -qi 'closure' /tmp/issue76-coverage-lint-selftest.out 2>/dev/null"

assert_true "AC-b-3: --self-test output names the exclusion leg (tests/lib, run-doc-invariants.sh, issue-59 driver asserted excluded; an outside path asserted NOT excluded)" \
  "grep -qi 'exclusion' /tmp/issue76-coverage-lint-selftest.out 2>/dev/null"

# ---------------------------------------------------------------------------
# AC-c-2 — trigger-window preservation over e2e-dummy-target.yml. Recomputes
# the fixed grep -A40 window below the FIRST paths: key and re-asserts every
# literal the three window-dependent live suites require, per
# `contract-suite-workflow`'s measured saturation
# (tests/test-issue-799-inert-cleanup.sh, tests/test-issue-55-*,
# tests/test-issue-52-*).
# ---------------------------------------------------------------------------
FIRST_PATHS_LINE="$(grep -n '^ *paths:' "$CI_WORKFLOW" | head -1 | cut -d: -f1)"
assert_true "AC-c-2 pre: e2e-dummy-target.yml has a paths: block to window against" "[ -n '$FIRST_PATHS_LINE' ]"

if [ -n "$FIRST_PATHS_LINE" ]; then
  WINDOW="$(sed -n "${FIRST_PATHS_LINE},$((FIRST_PATHS_LINE + 40))p" "$CI_WORKFLOW")"
  # Literals named by the three window-dependent live suites at HEAD.
  # GATE:QUALITY FAIL #6 (ledger E14): checked only 1 of the 6 literals
  # test-issue-799-inert-cleanup.sh:336-339 actually requires inside the
  # window — the other 5 could be silently evicted without this leg ever
  # noticing. All six now asserted.
  WINDOW_LITERALS=(
    "README.md"
    "docs/submodule-common-rules.md"
    "docs/external-review-sequencing.md"
    "docs/INDEX.md"
    "docs/maintained-docs.md"
    "docs/git-workflow.md"
  )
  for lit in "${WINDOW_LITERALS[@]}"; do
    assert_true "AC-c-2: window literal survives inside the first paths: block's 40-line window — '$lit'" \
      "printf '%s\n' \"\$WINDOW\" | grep -qF '$lit'"
  done
fi

# ---------------------------------------------------------------------------
# deleted-suite-still-read — dangling-reference sweep over the retirement
# set (GATE:QUALITY FAIL #2, ledger E14). Now that migration has landed,
# 843/844/the pre-split 951 suite, and the doc-invariants-baseline.txt
# fixture, are genuinely gone at HEAD; the sweep is a real assertion, not
# the `"true"` stub the prior round shipped (whose own justifying comment
# was already false at HEAD — the suites ARE deleted).
#
# Classification rule, stated because "comment-only mentions are harmless"
# (verification design, deleted-suite-still-read) needs a mechanical
# separation, not an eyeball one:
#   1. A hit on a line whose trimmed content starts with '#' is a
#      COMMENT — exempt. This is where a historical/provenance citation
#      lives (e.g. tests/test-issue-69-verification-depth.sh's "Moved here
#      from the permanent registry (GATE:QUALITY attempt-2 finding):
#      ... tests/test-issue-951-registry.sh, FINDING 3-E" — citing WHERE a
#      finding originated, not depending on that file existing).
#   2. A hit inside a file whose OWN declared purpose is a durable record
#      of what this cycle deleted and why — tests/fixtures/issue-76-
#      migration-map.md and docs/doc-invariant-registry.md — is exempt at
#      the FILE level: a "dangling reference" concern does not apply to a
#      document whose entire job is to name deleted things.
#   3. Everything else is a LIVE reference and fails the assertion — this
#      is what would previously have caught a suite's own SUITES[]/
#      DELETED_SUITES[] data array (a non-comment, non-provenance-file
#      line) content-referencing a target that no longer resolves.
DELETED_TARGETS=(
  "test-issue-843-doc-assertions.sh"
  "test-issue-844-doc-assertions.sh"
  "test-issue-951-registry.sh"
  "doc-invariants-baseline.txt"
)
EXEMPT_PROVENANCE_FILES=(
  "tests/fixtures/issue-76-migration-map.md"
  "docs/doc-invariant-registry.md"
  # tests/test-issue-76-migration-map-total.sh's SUITES[] array names
  # 843/844 as base-ref subjects it materialises via `git show
  # <base>:<path>` (see its own RED2 header note) — it never reads the
  # working-tree path, so a deletion cannot turn it red the way the
  # design's failure mode describes. Same exemption class as the map
  # document itself.
  "tests/test-issue-76-migration-map-total.sh"
  # tests/test-issue-76-runner-self-test-contract.sh's AC-f body-equality
  # leg materialises tests/test-issue-844-doc-assertions.sh via the same
  # `git show <base>:<path>` pattern (never the working-tree path) to
  # re-derive the deleted suite's own Resume-procedure extractor.
  "tests/test-issue-76-runner-self-test-contract.sh"
)
is_exempt_provenance_file() {
  local rel="$1" f
  for f in "${EXEMPT_PROVENANCE_FILES[@]}"; do
    [ "$rel" = "$f" ] && return 0
  done
  return 1
}
for name in "${DELETED_TARGETS[@]}"; do
  live_hits=()
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    hfile="${hit%%:*}"
    hrel="${hfile#"$PROJECT_ROOT"/}"
    [ "$hrel" = "tests/test-issue-76-orphan-registration.sh" ] && continue
    [ "$hrel" = "$name" ] && continue
    if is_exempt_provenance_file "$hrel"; then
      echo "  INFO: $name — exempt (provenance record): $hrel"
      continue
    fi
    hcontent="${hit#*:*:}"
    trimmed="$(printf '%s' "$hcontent" | sed -e 's/^[[:space:]]*//')"
    case "$trimmed" in
      \#*)
        echo "  INFO: $name — exempt (comment-only): $hit"
        ;;
      *)
        echo "  INFO: $name — LIVE reference: $hit"
        live_hits+=("$hit")
        ;;
    esac
  done < <(grep -rn -- "$name" "$PROJECT_ROOT/tests" "$PROJECT_ROOT/scripts" "$PROJECT_ROOT/docs" "$PROJECT_ROOT/.github" 2>/dev/null || true)
  assert_true "deleted-suite-still-read: no live (non-comment, non-provenance-file) reference to deleted target '$name' survives" \
    "[ ${#live_hits[@]} -eq 0 ]"
done

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
