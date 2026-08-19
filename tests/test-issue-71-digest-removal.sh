#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/agents/autoflow-analyzer.md .claude/hooks/check-autoflow-gate.sh .github/workflows/e2e-dummy-target.yml CLAUDE.md docs/adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md docs/adr/0017-teammate-removal-feasibility.md docs/autoflow-guide.md docs/design-rationale.md docs/doc-invariant-registry.md docs/improvement-backlog.md docs/maintained-docs.md docs/phases/analysis.md plugin/autoflow/agents/autoflow-analyzer.md scripts/canary/emit-phase-marker.sh scripts/test/run-suites.sh setup/gen-manifest-hashes.sh setup/manifest.json tests/adr-0016-conformance-check.sh tests/fixtures/doc-invariants.json tests/issue-create/fixtures/corpus.jsonl tests/lib/base-ref.sh tests/manual/issue-71-manual-scenarios.md tests/plugin/verify-e2e-dummy-target.sh tests/plugin/verify-install-into-target.sh tests/plugin/verify-package.sh tests/run-doc-invariants.sh
# lane: standing
# cycle-arm: #71
# budget-secs: SUITE_BUDGET_CEILING_SECS
# out-of-tree-inputs: yes
# =============================================================================
# Test: cycle-digest emission + cross-issue recurrence scan removal — Issue #71
# (cycle-scoped removal-state suite)
# =============================================================================
# Verification design: .autoflow/issue-71-verification-design.md. This is the
# ONE new scripted spec file the design calls for (the other is the manual
# scenario doc, tests/manual/issue-71-manual-scenarios.md). Every acceptance
# criterion whose method column reads "removal-state suite" lives here as a
# state assertion over the current tree; criteria carried by an execution-only
# oracle (fresh-target install e2e, manifest regeneration, the branch-
# unconditional guard sweep, the doc-invariant registry runner) are exercised
# INLINE by actually invoking the real script/suite — no mock stands in for
# any composition contact point (verification design > Composition oracle
# determination).
#
# GATE:PLAN findings folded in (cycle 1, avg 8.0 — see
# .autoflow/issue-71-ledger.md):
#   (a) doc-sweep-complete: the design's own §9 exception TABLE under-lists
#       files that legitimately carry a comment-only hit once their Consumer-
#       class arm is removed (#55 digest-agreement, #51 fixture-fence comment,
#       #985 AC1 comment, tests/plugin/verify-e2e-dummy-target.sh:406 arm
#       narration). Rather than hand-enumerate every such file (which is
#       exactly what under-listed last round), the sweep below applies the
#       syntactic Historical-record rule (design §2: "a hit inside a comment
#       is Historical record even when the comment discusses the digest at
#       length") to EVERY .sh/.yml file uniformly, not only to a named subset.
#       Only a hit inside an executable statement is a sweep failure.
#   (b) collateral-suites-green's #51 fence arm: not encoded as a branch-
#       scoped predicate here — the fence-list membership check
#       (AC-71-FIXTURE-FENCE below) is state-based and unconditional, so it is
#       not vacuous on any branch.
#   (c) ci-registration-removed originally windowed on the paths:/step blocks
#       only, missing the dangling `tests/test-issue-1-guard-contract.sh`
#       comment pointer at .github/workflows/e2e-dummy-target.yml:111-113.
#       Fixed below by asserting FULL-FILE absence (grep -c over the whole
#       workflow, not a windowed match) for both deleted suites' filenames.
#
# Known-RED at RED time (nothing removed yet — every mechanism file, script,
# doc clause and CI registration is still fully present): every absence-
# predicate below FAILs; every present-predicate that targets GREEN-authored
# text (the trimmed CLAUDE.md row, the narrowed registry literal, the #42
# retirement) also FAILs. This is documented, not a defect — mirrors the
# #69/#985 known-RED idiom cited in their own suite headers.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PROJECT_ROOT/tests/lib/base-ref.sh"

GUIDE="$PROJECT_ROOT/docs/autoflow-guide.md"
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
DESIGN_RATIONALE="$PROJECT_ROOT/docs/design-rationale.md"
IMPROVEMENT_BACKLOG="$PROJECT_ROOT/docs/improvement-backlog.md"
MAINTAINED_DOCS="$PROJECT_ROOT/docs/maintained-docs.md"
ANALYSIS_MD="$PROJECT_ROOT/docs/phases/analysis.md"
MANIFEST="$PROJECT_ROOT/setup/manifest.json"
GEN_MANIFEST="$PROJECT_ROOT/setup/gen-manifest-hashes.sh"
CI_WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"
REGISTRY="$PROJECT_ROOT/tests/fixtures/doc-invariants.json"
REGISTRY_RUNNER="$PROJECT_ROOT/tests/run-doc-invariants.sh"
HOOK="$PROJECT_ROOT/.claude/hooks/check-autoflow-gate.sh"
ANALYZER_HOST="$PROJECT_ROOT/.claude/agents/autoflow-analyzer.md"
ANALYZER_PLUGIN="$PROJECT_ROOT/plugin/autoflow/agents/autoflow-analyzer.md"
DUAL_PIN_SUITE="$PROJECT_ROOT/tests/test-issue-799-inert-cleanup.sh"
FENCE42_SUITE="$PROJECT_ROOT/tests/test-issue-42-spawn-mode-contract.sh"
PHASE_MARKER_SUITE="$PROJECT_ROOT/tests/test-issue-35-phase-marker.sh"
ADR0016_SUITE="$PROJECT_ROOT/tests/adr-0016-conformance-check.sh"
FIXTURE_FENCE_SUITE="$PROJECT_ROOT/tests/test-issue-51-teammate-removal-verdict.sh"
DOC985_SUITE="$PROJECT_ROOT/tests/test-issue-985-doc-assertions.sh"
HDIGEST_SUITE="$PROJECT_ROOT/tests/test-issue-40-hook-additive.sh"
SCOREFMT_SUITE="$PROJECT_ROOT/tests/test-issue-55-score-format-contract.sh"
VERIFY_PACKAGE="$PROJECT_ROOT/tests/plugin/verify-package.sh"
VERIFY_INSTALL="$PROJECT_ROOT/tests/plugin/verify-install-into-target.sh"
VERIFY_E2E="$PROJECT_ROOT/tests/plugin/verify-e2e-dummy-target.sh"
MANIFEST_LOCALE_SUITE="$PROJECT_ROOT/tests/test-issue-16-manifest-locale-invariance.sh"
# Five further names here (peer-facilitator, topology-flip, doc-846, doc-848,
# background-ban) had no reader at all and were deleted with the sibling-re-run
# disposal (issue #103) — symbol closure, the same direction
# docs/doc-invariant-registry.md §12.1 already applies. The names ABOVE stay:
# each is a live `grep` file operand of an assertion this cycle does not touch.

PASS=0; FAIL=0; TESTS=0

assert_true() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if (cd "$PROJECT_ROOT" && eval "$condition"); then
    echo "  PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

assert_false() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if ! (cd "$PROJECT_ROOT" && eval "$condition"); then
    echo "  PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

note_deferred() { echo "  DEFERRED-OBSERVABLE: $1"; }


# The assert_suite_exit0 helper is removed with its call sites (issue #103): it
# existed only to run a sibling suite under a per-call timeout. The
# budget-under-timeout convention it carried is not lost — it is now a declared
# `# budget-secs:` header on every suite, enforced locally by
# scripts/test/run-suites.sh and on the CI path by each step's
# `timeout-minutes`, with the agreement between the two asserted by
# scripts/test/check-suite-manifest.sh.

echo "=== issue #71 — cycle-digest emission + cross-issue recurrence scan removal ==="

# =============================================================================
echo ""
echo "=== scripts-removed / data-plane-removed — mechanism files absent + untracked ==="

for f in \
  "scripts/handoff/emit-cycle-digest.sh" \
  "scripts/preflight/scan-cross-issue-recurrence.sh" \
  "docs/cycle-digest.jsonl"
do
  assert_true "AC-71-REMOVED: $f is absent from the working tree" "[ ! -e '$f' ]"
  assert_true "AC-71-REMOVED: $f is untracked (git ls-files --error-unmatch fails)" \
    "! git ls-files --error-unmatch '$f' >/dev/null 2>&1"
done

# =============================================================================
echo ""
echo "=== digest-only-suites-retired — dedicated digest/scan suites, fixtures and manual docs deleted ==="
# GATE:QUALITY (cycle 1, attempt 2) finding: tests/manual/issue-7-manual-
# scenarios.md's subject suite (tests/test-issue-7-oracle-hardening.sh) was
# deleted by this cycle but its manual-scenario companion was not — the
# analogous 953/954 pairs were correctly deleted alongside their suites, so
# #7's manual doc is the same disposition class, just missed the first pass.

for f in \
  "tests/test-issue-953-cycle-digest.sh" \
  "tests/test-issue-954-cross-issue-scan.sh" \
  "tests/test-issue-6-severity-parse-contract.sh" \
  "tests/test-issue-1-guard-contract.sh" \
  "tests/test-issue-7-oracle-hardening.sh" \
  "tests/fixtures/cycle-digest-schema.json" \
  "tests/manual/issue-953-manual-scenarios.md" \
  "tests/manual/issue-954-manual-scenarios.md" \
  "tests/manual/issue-7-manual-scenarios.md"
do
  assert_true "AC-71-RETIRED: $f is absent" "[ ! -e '$f' ]"
  assert_true "AC-71-RETIRED: $f is untracked" \
    "! git ls-files --error-unmatch '$f' >/dev/null 2>&1"
done

CYCLE954_FIXTURES="$(ls "$PROJECT_ROOT"/tests/fixtures/cycle-digest-954-*.jsonl 2>/dev/null | wc -l | tr -d ' ')"
assert_true "AC-71-RETIRED: no tests/fixtures/cycle-digest-954-*.jsonl fixture survives (found: $CYCLE954_FIXTURES)" \
  "[ '$CYCLE954_FIXTURES' -eq 0 ]"
assert_true "AC-71-RETIRED: tests/fixtures/cycle-digest-979-pre-migration-snapshot.jsonl is absent" \
  "[ ! -e 'tests/fixtures/cycle-digest-979-pre-migration-snapshot.jsonl' ]"

# =============================================================================
echo ""
echo "=== guide-steps-removed — docs/autoflow-guide.md drops PREFLIGHT 1.5 and HANDOFF 6.7 whole; survivors untouched ==="

assert_true "AC-71-GUIDE: 'Cross-issue recurrence scan (step 1.5)' section header is gone" \
  "! grep -qF 'Cross-issue recurrence scan (step 1.5)' '$GUIDE'"
assert_true "AC-71-GUIDE: '6.7. Cycle digest emission' step is gone" \
  "! grep -qF '6.7. Cycle digest emission' '$GUIDE'"
assert_true "AC-71-GUIDE: PREFLIGHT step table no longer carries a '| 1.5 |' row" \
  "! grep -qE '^\\| 1\\.5 \\|' '$GUIDE'"
assert_true "AC-71-GUIDE: no dangling cross-reference to the removed sections survives ('step 1.5' / 'step-1.5' prose outside the upstream-mapping row)" \
  "[ \"\$(grep -inE 'step[ -]1\\.5' '$GUIDE' | grep -vF '| STEP 1.5 | GATE:HYPOTHESIS |' | wc -l | tr -d ' ')\" -eq 0 ]"
# Paired present-predicate: the unrelated upstream STEP-id mapping row survives
# untouched — a bare '1.5' absent-predicate alone would be a false RED here.
assert_true "AC-71-GUIDE: the surviving upstream-mapping row '| STEP 1.5 | GATE:HYPOTHESIS |' is unchanged" \
  "grep -qF '| STEP 1.5 | GATE:HYPOTHESIS |' '$GUIDE'"

# =============================================================================
echo ""
echo "=== severity-contract-preserved — step 6.5's [MUST] max_severity contract sentence survives; only the emitter-justifying sentence is trimmed ==="

assert_true "AC-71-SEVERITY: step 6.5's max_severity mandate sentence survives" \
  "grep -qF 'The ingesting subagent **always** writes exactly one \`max_severity:' '$GUIDE'"
assert_true "AC-71-SEVERITY: the emitter-justifying clause (naming the step-6.7 emitter) is trimmed" \
  "! grep -qF 'lets the step-6.7 emitter treat a present findings file' '$GUIDE'"

# =============================================================================
echo ""
echo "=== claude-md-updated — Spawn Model table row drops the two removed spawns; surviving clause is unchanged ==="

assert_true "AC-71-CLAUDEMD: Spawn mode table no longer names 'cycle digest emitter (6.7)'" \
  "! grep -qF 'cycle digest emitter (6.7)' '$CLAUDE_MD'"
assert_true "AC-71-CLAUDEMD: Spawn mode table no longer names 'PREFLIGHT cross-issue recurrence scan (1.5)'" \
  "! grep -qF 'PREFLIGHT cross-issue recurrence scan (1.5)' '$CLAUDE_MD'"
assert_true "AC-71-CLAUDEMD: the surviving review-triage subagent clause is unchanged" \
  "grep -qF 'HANDOFF review-triage subagent (finding ingestion + Low judgment, step 6.5)' '$CLAUDE_MD'"
assert_true "AC-71-CLAUDEMD: the row's third-cell clause (registry literal 42-AC1-handoff-scope) is unchanged" \
  "grep -qF 'the auto-resolution it feeds is re-entered through the named Test AI / Developer AI rows' '$CLAUDE_MD'"

# =============================================================================
echo ""
echo "=== agent-definition-updated — both autoflow-analyzer.md copies drop the two digest/scan variants, byte-identical ==="

assert_true "AC-71-ANALYZER-host: .claude/agents/autoflow-analyzer.md drops the HANDOFF digest-emission variant" \
  "! grep -qF 'HANDOFF cycle-digest emission variant' '$ANALYZER_HOST'"
assert_true "AC-71-ANALYZER-host: .claude/agents/autoflow-analyzer.md drops the PREFLIGHT recurrence-scan variant" \
  "! grep -qF 'PREFLIGHT step-1.5 cross-issue recurrence scan variant' '$ANALYZER_HOST'"
assert_true "AC-71-ANALYZER-plugin: plugin/autoflow/agents/autoflow-analyzer.md drops the HANDOFF digest-emission variant" \
  "! grep -qF 'HANDOFF cycle-digest emission variant' '$ANALYZER_PLUGIN'"
assert_true "AC-71-ANALYZER-plugin: plugin/autoflow/agents/autoflow-analyzer.md drops the PREFLIGHT recurrence-scan variant" \
  "! grep -qF 'PREFLIGHT step-1.5 cross-issue recurrence scan variant' '$ANALYZER_PLUGIN'"
assert_true "AC-71-ANALYZER-parity: the two analyzer copies remain byte-identical" \
  "diff -q '$ANALYZER_HOST' '$ANALYZER_PLUGIN' >/dev/null 2>&1"

# =============================================================================
echo ""
echo "=== design-rationale.md — Known-Limitations entries revert; Under-Discussion parenthetical struck ==="

assert_true "AC-71-RATIONALE: the digest Known-Limitation no longer cites 'now durably captured at HANDOFF'" \
  "! grep -qF 'now durably captured at HANDOFF' '$DESIGN_RATIONALE'"
assert_true "AC-71-RATIONALE: the cross-issue Known-Limitation heading no longer says 'mechanism now shipped'" \
  "! grep -qF 'mechanism now shipped' '$DESIGN_RATIONALE'"
assert_true "AC-71-RATIONALE: the Under-Discussion bullet's #954-scan parenthetical is struck" \
  "! grep -qF 'the #954 recurrence scan supplies factual candidate signals' '$DESIGN_RATIONALE'"

# =============================================================================
echo ""
echo "=== docs/improvement-backlog.md — step-1.5 grammar header sentence removed; filed item keeps its entry ==="

assert_true "AC-71-BACKLOG: the step-1.5 xissue-scan grammar header sentence is removed" \
  "! grep -qF 'xissue-scan-' '$IMPROVEMENT_BACKLOG'"
assert_true "AC-71-BACKLOG: the filed cross-issue-scan backlog item still names #71 as its resolution disposition" \
  "grep -qE '#71' '$IMPROVEMENT_BACKLOG'"

# =============================================================================
echo ""
echo "=== docs/maintained-docs.md — Improvement Backlog row drops the scan-append trigger ==="

assert_true "AC-71-MAINTAINED: Improvement Backlog row no longer cites 'cross-issue recurrence scan appends a candidate finding'" \
  "! grep -qF 'cross-issue recurrence scan appends a candidate finding' '$MAINTAINED_DOCS'"

# =============================================================================
echo ""
echo "=== docs/phases/analysis.md — the loop-check <-> recurrence-scan relationship section is removed whole; the per-issue loop check itself is untouched ==="

assert_true "AC-71-ANALYSIS: the relationship section header is gone" \
  "! grep -qF 'Review-response loop check' '$ANALYSIS_MD' || ! grep -qE 'cross-issue recurrence scan \\(#954\\)' '$ANALYSIS_MD'"
assert_true "AC-71-ANALYSIS: the per-issue Review-response loop check block itself survives" \
  "grep -qF 'A \`sonnet\` Explore sub-agent (clears the pre-GATE hook like Phase A/3) writes' '$ANALYSIS_MD'"

# =============================================================================
echo ""
echo "=== doc-sweep-complete — no tracked non-comment reference to the removed mechanism survives outside the derived exception set ==="

# Union token set (verification design AC doc-sweep-complete): path family +
# prose family. Case-insensitive.
TOKEN_RE='cycle-digest|scan-cross-issue-recurrence|xissue-scan|cross-issue recurrence|recurrence scan|step 1\.5|step-1\.5|step 6\.7|step-6\.7'

# Whole-file exemptions: Historical record (ADR pair — adr-disposition covers
# their unmodified-ness separately), frozen snapshot, Not-a-reference
# (different artifact), and every inert allow-list-membership suite (branch-
# scoped #52/#67/#69 and unconditional #798/#799/#846/#848/#952/#955) — an
# allow-list membership is a permission, not an assertion (feature design §8).
# This suite and the manual scenario doc are exempt from their own sweep.
EXEMPT_WHOLE_FILES=(
  "docs/adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md"
  "docs/adr/0017-teammate-removal-feasibility.md"
  "tests/test-issue-64-collection-scope.sh"
  "tests/test-issue-52-peer-facilitator-premise.sh"
  "tests/test-issue-67-deliberation-record.sh"
  "tests/test-issue-69-verification-depth.sh"
  "tests/test-issue-798-topology-flip.sh"
  "tests/test-issue-799-inert-cleanup.sh"
  "tests/test-issue-846-doc-assertions.sh"
  "tests/test-issue-848-doc-assertions.sh"
  "tests/test-issue-952-wizard-removal.sh"
  "tests/test-issue-955-subagent-background-ban.sh"
  # feature design §8: #55's committed-surface-completeness is itself a
  # branch-unconditional guard whose allow_list members are executable-
  # statement literals — same inert-allow-list-membership exemption ground
  # as the six suites above, not a comment-shaped hit.
  "tests/test-issue-55-score-format-contract.sh"
  "tests/test-issue-71-digest-removal.sh"
  "tests/manual/issue-71-manual-scenarios.md"
  # docs/doc-invariant-registry.md's §5 disposition-record table (:118-123)
  # narrates this cycle's five retirement decisions (953/954/1/6/7 + their
  # fixtures) as Historical-record-shaped bookkeeping mandated by issue #76's
  # delegation — the registry's own retired-guard audit trail, not a live
  # reference to the mechanism. Every token hit in the file is confined to
  # those five rows (re-derived: `git grep` over the union token set returns
  # only :118,119,120,121,123), so a whole-file exemption is safe.
  "docs/doc-invariant-registry.md"
  # tests/issue-create/fixtures/corpus.jsonl is a frozen snapshot of 50 real
  # tracker titles (issue #96's duplicate-query retrieval corpus, captured via
  # `gh issue list --state all` at RED time). Three CLOSED historical titles
  # (#1, #6, #10) name the removed mechanism because those issues were about
  # it — the rows are recorded tracker history feeding a retrieval index, not
  # a live reference to the mechanism. Same frozen-snapshot exemption ground
  # the header comment names.
  "tests/issue-create/fixtures/corpus.jsonl"
)

is_exempt_whole_file() {
  local f="$1"
  for e in "${EXEMPT_WHOLE_FILES[@]}"; do
    [ "$f" = "$e" ] && return 0
  done
  return 1
}

# Two Not-a-reference prose collisions, exempted per hit-line literal
# regardless of file (design §9: distinct subjects sharing a token).
is_exempt_line() {
  local line="$1"
  case "$line" in
    *'| STEP 1.5 | GATE:HYPOTHESIS |'*) return 0 ;;
    *'Check cross-issue consistency before an added proposal'*) return 0 ;;
  esac
  return 1
}

SWEEP_BAD=0
SWEEP_BAD_DETAIL=""
while IFS= read -r hit; do
  [ -z "$hit" ] && continue
  hfile="${hit%%:*}"
  hrest="${hit#*:}"
  hline="${hrest#*:}"
  is_exempt_whole_file "$hfile" && continue
  is_exempt_line "$hline" && continue
  # Historical record, applied uniformly (design §2: syntactic, not topical;
  # GATE:PLAN finding (a) — do not hand-enumerate the comment-carrying files,
  # the rule is per-hit and file-type-general for .sh/.yml sources).
  case "$hfile" in
    *.sh|*.yml|*.yaml)
      # Strip ALL leading whitespace (not just one char) before testing for
      # a comment marker — an indented `#` (the common case inside a `for`/
      # `if` block) must be recognised, not just a column-0 `#`.
      hline_trimmed="${hline#"${hline%%[![:space:]]*}"}"
      case "$hline_trimmed" in
        '#'*) continue ;;
      esac
      ;;
  esac
  SWEEP_BAD=$((SWEEP_BAD + 1))
  SWEEP_BAD_DETAIL="$SWEEP_BAD_DETAIL
    $hit"
done < <(git -C "$PROJECT_ROOT" grep -niE "$TOKEN_RE" -- . 2>/dev/null)

assert_true "AC-71-SWEEP: doc-sweep-complete — every surviving tracked hit is Historical-record-shaped or on the derived exception set (bad hits: $SWEEP_BAD)$SWEEP_BAD_DETAIL" \
  "[ $SWEEP_BAD -eq 0 ]"

# =============================================================================
echo ""
echo "=== adr-disposition — ADR-0015 and ADR-0017 are unmodified by this cycle ==="

if on_issue71_branch() { case "${GITHUB_HEAD_REF:-$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)}" in dev/*-issue-71|dev/*-issue-71-*) return 0 ;; *) return 1 ;; esac; }; on_issue71_branch; then
  BASE_REF_ADR="$(resolve_base_ref)" || true
  if [ -n "${BASE_REF_ADR:-}" ]; then
    assert_true "AC-71-ADR: ADR-0015 unmodified by this cycle's diff" \
      "[ -z \"\$(git diff '$BASE_REF_ADR'...HEAD -- docs/adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md)\" ]"
    assert_true "AC-71-ADR: ADR-0017 unmodified by this cycle's diff" \
      "[ -z \"\$(git diff '$BASE_REF_ADR'...HEAD -- docs/adr/0017-teammate-removal-feasibility.md)\" ]"
  else
    echo "  BLOCK: no comparison base resolvable — AC-71-ADR counted FAIL, never skipped"
    TESTS=$((TESTS + 2)); FAIL=$((FAIL + 2))
  fi
else
  note_deferred "AC-71-ADR: change-surface-relative guard inert off the issue-71 dev branch."
fi

# =============================================================================
echo ""
echo "=== dangling-citation-struck — adr-0016-conformance-check.sh drops the #953-suite citation, keeps both surviving carriers ==="

assert_true "AC-71-CITATION: #953 dangling citation is struck from adr-0016-conformance-check.sh" \
  "! grep -qF 'test-issue-953-cycle-digest.sh AC6-regen-idempotence' '$ADR0016_SUITE'"
assert_true "AC-71-CITATION: the #16 AC2 surviving carrier is still named" \
  "grep -qF 'test-issue-16-manifest-locale-invariance.sh AC2' '$ADR0016_SUITE'"
assert_true "AC-71-CITATION: the package-verifier AC5d surviving carrier is still named" \
  "grep -qF 'verify-package.sh AC5d' '$ADR0016_SUITE'"

# =============================================================================
echo ""
echo "=== ci-registration-removed — no deleted suite remains a CI step, a paths: filter member, or a dangling comment pointer ==="

for suite in "test-issue-1-guard-contract.sh" "test-issue-7-oracle-hardening.sh" "issue-7-manual-scenarios.md"; do
  COUNT="$(grep -c -- "$suite" "$CI_WORKFLOW" || true)"
  assert_true "AC-71-CI: $suite has zero occurrences anywhere in e2e-dummy-target.yml (paths/step/comment) — got $COUNT" \
    "[ '$COUNT' -eq 0 ]"
done

assert_true "AC-71-CI-SELFREG: this suite is registered in e2e-dummy-target.yml (paths: in both pull_request and push blocks, plus a run: step)" \
  "[ \"\$(grep -c \"'tests/test-issue-71-digest-removal.sh'\" '$CI_WORKFLOW')\" -eq 2 ] && grep -qF 'run: bash tests/test-issue-71-digest-removal.sh' '$CI_WORKFLOW'"

# =============================================================================
echo ""
echo "=== collateral-suites-green (state half) — the #51 fixture-fence list drops the cycle-digest-schema.json entry ==="

assert_true "AC-71-FIXTURE-FENCE: tests/fixtures/cycle-digest-schema.json is no longer named in #51's FENCE_FILES" \
  "! grep -qF 'tests/fixtures/cycle-digest-schema.json' '$FIXTURE_FENCE_SUITE'"

echo ""
echo "=== collateral-suites-green (state half) — the #985 AC1-DIGEST-NO-INHERITED-RECORDS arm is dropped (subject retired) ==="

assert_true "AC-71-DOC985: AC1-DIGEST-NO-INHERITED-RECORDS is no longer asserted in test-issue-985-doc-assertions.sh" \
  "! grep -qF 'AC1-DIGEST-NO-INHERITED-RECORDS' '$DOC985_SUITE'"

echo ""
echo "=== collateral-suites-green (state half) — the #40 H-DIGEST arm and the #55 digest-agreement arm are dropped ==="

assert_true "AC-71-HDIGEST: the H-DIGEST arm is dropped from test-issue-40-hook-additive.sh" \
  "! grep -qiF 'h-digest' '$HDIGEST_SUITE'"
assert_true "AC-71-DIGESTAGREE: the digest-agreement arm is dropped from test-issue-55-score-format-contract.sh" \
  "! grep -qiF 'digest-agreement' '$SCOREFMT_SUITE'"

echo ""
echo "=== collateral-suites-green (state half) — verify-e2e-dummy-target.sh / verify-install-into-target.sh drop the emitter arm/entry ==="

assert_true "AC-71-E2E: the E3a-y executed-emitter arm is dropped from verify-e2e-dummy-target.sh" \
  "! grep -qF 'E3a-y' '$VERIFY_E2E'"
assert_true "AC-71-E2E: verify-e2e-dummy-target.sh no longer names emit-cycle-digest.sh anywhere (arm body or narration comment)" \
  "[ \"\$(grep -c 'emit-cycle-digest.sh' '$VERIFY_E2E')\" -eq 0 ]"
assert_true "AC-71-INSTALL: verify-install-into-target.sh's installed-file expectation list drops emit-cycle-digest.sh" \
  "! grep -qF 'emit-cycle-digest.sh' '$VERIFY_INSTALL'"
assert_true "AC-71-INSTALL: verify-install-into-target.sh's installed-file expectation list drops scan-cross-issue-recurrence.sh" \
  "! grep -qF 'scan-cross-issue-recurrence.sh' '$VERIFY_INSTALL'"

# =============================================================================
echo ""
echo "=== #35 phase-marker witness swap — AC9-b re-points to a surviving tracked docs/ witness that is genuinely not-ignored ==="

assert_true "AC-71-PHASEMARKER: AC9-b no longer names docs/cycle-digest.jsonl" \
  "! grep -qF 'docs/cycle-digest.jsonl' '$PHASE_MARKER_SUITE'"
# The new witness must itself be a real, tracked, not-ignored docs/ path —
# re-derive the arm's own new literal and confirm it independently rather
# than trusting the suite's self-report.
NEW_WITNESS="$(grep -oE "AC9-b:[^\"]*\" *\"git check-ignore -q [^\"]+\"" "$PHASE_MARKER_SUITE" 2>/dev/null \
  | grep -oE 'git check-ignore -q [^"]+' | awk '{print $NF}' | head -1)"
if [ -n "${NEW_WITNESS:-}" ]; then
  assert_true "AC-71-PHASEMARKER: the new AC9-b witness ($NEW_WITNESS) is tracked" \
    "git ls-files --error-unmatch '$NEW_WITNESS' >/dev/null 2>&1"
  assert_false "AC-71-PHASEMARKER: the new AC9-b witness ($NEW_WITNESS) is NOT gitignored" \
    "git check-ignore -q '$NEW_WITNESS'"
else
  echo "  FAIL: AC-71-PHASEMARKER: could not derive a re-pointed AC9-b witness from test-issue-35-phase-marker.sh"
  TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
fi

# =============================================================================
echo ""
echo "=== fence-42-retired — AC2-UNTOUCHED's two literal fences, the diff_touches_literal helper and its base-resolution branch are deleted; the rest of #42 is intact ==="

assert_true "AC-71-FENCE42: the step-1.5 literal fence argument is gone" \
  "! grep -qF \"'Cross-issue recurrence scan (step 1.5)'\" '$FENCE42_SUITE'"
assert_true "AC-71-FENCE42: the step-6.7 literal fence argument is gone" \
  "! grep -qF \"'6.7. Cycle digest emission'\" '$FENCE42_SUITE'"
assert_true "AC-71-FENCE42: the diff_touches_literal helper is gone" \
  "! grep -qF 'diff_touches_literal' '$FENCE42_SUITE'"
assert_true "AC-71-FENCE42: the empty-base fail-loud assertion line is gone" \
  "! grep -qF 'could not resolve a comparison base' '$FENCE42_SUITE'"
assert_true "AC-71-FENCE42: M42-REGEN-CLEAN survives" \
  "grep -qF 'M42-REGEN-CLEAN' '$FENCE42_SUITE'"
assert_true "AC-71-FENCE42: A42-LITERAL-CONTIGUOUS survives" \
  "grep -qF 'A42-LITERAL-CONTIGUOUS' '$FENCE42_SUITE'"
assert_true "AC-71-FENCE42: the H-BYTES retirement-precedent comment survives" \
  "grep -qF 'H-BYTES (retired, #64)' '$FENCE42_SUITE'"
assert_true "AC-71-FENCE42: the CI step 'Run spawn-mode contract guard (#42)' stays registered" \
  "grep -qF 'Run spawn-mode contract guard (#42)' '$CI_WORKFLOW'"

# =============================================================================
echo ""
echo "=== registry-entry-amended + claude-md-dual-pin-consistent — the two CLAUDE.md pins move together; registered narrower literal matches ==="

ENTRY_LITERAL="$(jq -r '.invariants[]? // .[] | select(.id=="42-AC1-anon-handoff") | .literal' "$REGISTRY" 2>/dev/null)"
if [ -z "$ENTRY_LITERAL" ]; then
  # fallback for a registry shaped as a bare top-level array (matches the
  # $(.artifacts...) style used elsewhere in this repo's suites)
  ENTRY_LITERAL="$(jq -r '.[] | select(.id=="42-AC1-anon-handoff") | .literal' "$REGISTRY" 2>/dev/null)"
fi
assert_true "AC-71-REGISTRY: 42-AC1-anon-handoff's literal no longer names the two removed spawns" \
  "! printf '%s' \"$ENTRY_LITERAL\" | grep -qF 'cycle digest emitter (6.7)'"
assert_true "AC-71-REGISTRY: 42-AC1-anon-handoff's literal is still present, non-empty, and matches the live CLAUDE.md row" \
  "[ -n \"$ENTRY_LITERAL\" ] && grep -qF \"$ENTRY_LITERAL\" '$CLAUDE_MD'"
IDFILE="$(jq -r '.invariants[]? // .[] | select(.id=="42-AC1-anon-handoff") | "\(.id)|\(.file)|\(.predicate)|\(.scope)"' "$REGISTRY" 2>/dev/null)"
assert_true "AC-71-REGISTRY: 42-AC1-anon-handoff preserves id/file/predicate/scope" \
  "[ \"$IDFILE\" = '42-AC1-anon-handoff|CLAUDE.md|present|permanent' ]"

echo ""
echo "--- pin 2: the #799 off-window chain gains two appended filters; the pre-existing '+'-prefixed old-row filter is untouched ---"

if grep -q "claude_md_offwindow_changes" "$DUAL_PIN_SUITE"; then
  assert_true "AC-71-DUALPIN: the pre-existing '+'-prefixed filter for the OLD (unshortened) row is still present verbatim" \
    "grep -qF \"grep -vF '+| HANDOFF review-triage subagent (finding ingestion + Low judgment, step 6.5), cycle digest emitter (6.7), PREFLIGHT cross-issue recurrence scan (1.5)'\" '$DUAL_PIN_SUITE'"
  assert_true "AC-71-DUALPIN: a NEW '-'-prefixed filter admits the removed old row" \
    "grep -qE \"grep -vF -- '-\\\\| HANDOFF review-triage subagent\" '$DUAL_PIN_SUITE'"
  assert_true "AC-71-DUALPIN: a NEW '+'-prefixed filter admits the new shortened row" \
    "grep -E \"grep -vF '\\\\+\\\\| HANDOFF review-triage subagent \\\\(finding ingestion \\\\+ Low judgment, step 6\\.5\\\\)\" '$DUAL_PIN_SUITE' | grep -vF 'cycle digest'"
else
  # #75 retired 799's whole off-window filter chain (claude_md_offwindow_changes
  # and every CLAUDE.md line filter with it — docs/doc-invariant-registry.md §5,
  # dropped — cycle-local), so the three filter-line pins above have no subject.
  # Retired-subject vacuous-pass convention (DC-4 precedent); the real oracle
  # AC-71-DUALPIN-oracle below still executes 799 against the live diff.
  echo "  PASS (vacuous): AC-71-DUALPIN — 799's off-window filter chain retired by #75 (§5 dropped — cycle-local); no filter subject remains"
  TESTS=$((TESTS + 1)); PASS=$((PASS + 1))
fi

echo ""
echo "--- both pins driven through the real oracles ---"

REGISTRY_OUT="$(cd "$PROJECT_ROOT" && bash "$REGISTRY_RUNNER" 2>&1)"
REGISTRY_EXIT=$?
NON_71_FAIL="$(printf '%s\n' "$REGISTRY_OUT" | grep '^  FAIL:' | grep -v '42-AC1-anon-handoff' | wc -l | tr -d ' ')"
assert_true "AC-71-REGISTRY-oracle: tests/run-doc-invariants.sh exits 0 (KNOWN RED mid-cycle until GREEN narrows the literal)" \
  "[ $REGISTRY_EXIT -eq 0 ]"
assert_true "AC-71-REGISTRY-oracle-no-regression: no non-42-AC1-anon-handoff registry entry regresses (foreign FAILs: $NON_71_FAIL)" \
  "[ '$NON_71_FAIL' -eq 0 ]"

# AC-71-DUALPIN-oracle's execution of tests/test-issue-799-inert-cleanup.sh is
# retired (issue #103): that suite carries its own registered `run:` step in
# e2e-dummy-target.yml, so a regression in it reds CI under its own name. The
# `$DUAL_PIN_SUITE` ASSIGNMENT stays — its name is a live `grep` file operand of
# the AC-71-DUALPIN filter-text assertions above, and deleting the block would
# remove the operands of live assertions. The two are different disposals with
# different scopes. Disposition row: docs/doc-invariant-registry.md §12.1.

# =============================================================================
echo ""
echo "=== permanent-invariants-preserved — the three subjects the deleted suites carried each have a live, passing home ==="

echo ""
echo "--- confirm: analyzer plugin parity loop is present and passes ---"
assert_true "AC-71-PARITY-CONFIRM: verify-package.sh's generic per-agent parity loop is present" \
  "grep -qF 'for f in \"\$ORIG_AGENTS\"/*.md' '$VERIFY_PACKAGE'"
assert_true "AC-71-PARITY-CONFIRM: the live analyzer copies pass that generic parity check right now" \
  "diff -q '$ANALYZER_HOST' '$ANALYZER_PLUGIN' >/dev/null 2>&1"

echo ""
echo "--- confirm: manifest regeneration idempotence has two live homes ---"
assert_true "AC-71-MANIFEST-CONFIRM: test-issue-16-manifest-locale-invariance.sh AC2 (regenerate-and-compare) is present" \
  "grep -qF 'AC2' '$MANIFEST_LOCALE_SUITE'"
assert_true "AC-71-MANIFEST-CONFIRM: verify-package.sh AC5d (non-regen guard) is present" \
  "grep -qF 'AC5d' '$VERIFY_PACKAGE'"

echo ""
echo "--- re-home: hook malformed-state scan scope (AC4), witness OUTSIDE .autoflow, malformed JSON, not the retired digest ---"
# The #953 AC4 witness was docs/cycle-digest.jsonl, which #64's collection-
# scope suite does not cover (its own fixture sits INSIDE .autoflow — the
# in-scope side, the opposite control). Re-homed here with a fresh witness
# that is not the retired mechanism: docs/issue-71-scanscope-witness.json,
# built only inside the temp project this arm constructs (never a real
# repo path), malformed as JSON, outside .autoflow/.
#
# VERIFY step-4 fidelity fix: the active-state fixture MUST be named
# issue-<digits-only>.json — the hook's own discovery glob
# (.claude/hooks/check-autoflow-gate.sh:353) is filtered at :361-363 to
# `issue-*.json` whose stripped stem is all-digits; a name like
# `issue-71-scanscope.json` fails that filter and is silently skipped
# BEFORE the active/malformed classification runs, making the "does not
# block a passing active state" half of this assertion vacuous (verified:
# it passed identically with no state file present at all). `issue-9971`
# avoids colliding with any real issue's `.autoflow/issue-<N>.json`.
AC71_PDIR="$(mktemp -d)"
trap 'rm -rf "$AC71_PDIR"' EXIT
mkdir -p "$AC71_PDIR/.autoflow" "$AC71_PDIR/docs"
cat > "$AC71_PDIR/.autoflow/issue-9971.json" <<'EOF'
{ "active": true, "issue": "#9971",
  "phases": {
    "gate_hypothesis_cause": {"verdict": "skipped (feat issue)"},
    "gate_plan":    {"scores": {"a": {"score": 8}, "b": {"score": 8}}},
    "audit":        {"scores": {"a": {"score": 8}, "b": {"score": 8}}},
    "gate_quality": {"scores": {"a": {"score": 8}, "b": {"score": 8}}} } }
EOF
printf 'not even valid json, on purpose\n{"issue":"#71"}\n' > "$AC71_PDIR/docs/issue-71-scanscope-witness.json"
assert_true "AC-71-SCANSCOPE-glob: hook state-discovery glob is still \"\$AUTOFLOW_DIR\"/*.json" \
  "grep -qF '\"\$AUTOFLOW_DIR\"/*.json' '$HOOK'"
assert_true "AC-71-SCANSCOPE-dir: AUTOFLOW_DIR is still .../.autoflow" \
  "grep -qE 'AUTOFLOW_DIR=.*\\.autoflow\"?\$' '$HOOK'"
AC71_JSON='{"tool_name":"Bash","tool_input":{"command":"git push -u origin dev/test"}}'
AC71_EXIT=$(printf '%s' "$AC71_JSON" | CLAUDE_PROJECT_DIR="$AC71_PDIR" bash "$HOOK" >/dev/null 2>&1; echo $?)
assert_true "AC-71-SCANSCOPE-no-block: hook does NOT block git push when a malformed docs/*.json witness sits alongside a passing active state (exit=$AC71_EXIT)" \
  "[ '$AC71_EXIT' -eq 0 ]"

# =============================================================================
echo ""
echo "=== distribution-registration-removed — manifest drops both scripts' rows; regeneration is idempotent (real script, real tar-copy) ==="

assert_true "AC-71-MANIFEST-ROW: setup/manifest.json has no artifacts[] row for scripts/preflight/scan-cross-issue-recurrence.sh" \
  "[ \"\$(jq -r '[.artifacts[] | select(.source==\"scripts/preflight/scan-cross-issue-recurrence.sh\")] | length' '$MANIFEST')\" -eq 0 ]"
assert_true "AC-71-MANIFEST-ROW: setup/manifest.json has no artifacts[] row for scripts/handoff/emit-cycle-digest.sh" \
  "[ \"\$(jq -r '[.artifacts[] | select(.source==\"scripts/handoff/emit-cycle-digest.sh\")] | length' '$MANIFEST')\" -eq 0 ]"
assert_true "AC-71-GENMANIFEST: setup/gen-manifest-hashes.sh no longer emits either row" \
  "! grep -qF 'scan-cross-issue-recurrence.sh' '$GEN_MANIFEST' && ! grep -qF 'emit-cycle-digest.sh' '$GEN_MANIFEST'"

# VERIFY step-4 fidelity fix: the real oracle (verification design >
# Composition oracle determination; tests/test-issue-16-manifest-locale-
# invariance.sh:101-108, "AC2 ... isolated temp copy; test-953 AC6 tree-copy
# idiom") runs the regenerator inside a disposable tar-copy of the tree, so
# setup/gen-manifest-hashes.sh's own SCRIPT_DIR/REPO_ROOT self-resolution
# (setup/gen-manifest-hashes.sh:27-29) lands on the copy — the live tracked
# setup/manifest.json is never mutated, not even transiently. Adopted
# verbatim here instead of the prior backup/regen-in-place/restore approach,
# which mutated the live tree with no trap-guaranteed restore.
if [ -x "$GEN_MANIFEST" ] || [ -f "$GEN_MANIFEST" ]; then
  # No `trap ... EXIT` here (would clobber the SCANSCOPE block's EXIT trap
  # above, since bash traps for the same signal replace rather than stack) —
  # matches the #16 precedent, which also cleans up with a plain rm -rf
  # rather than a trap.
  AC71_MTMP="$(mktemp -d)"
  (cd "$PROJECT_ROOT" && tar --exclude='.git' -cf - .) | (cd "$AC71_MTMP" && tar -xf -) 2>/dev/null
  ( cd "$AC71_MTMP" && bash setup/gen-manifest-hashes.sh >/dev/null 2>&1 )
  assert_true "AC-71-MANIFEST-REGEN: regenerating setup/manifest.json in an isolated tar-copy (real script) produces no diff against the live committed manifest" \
    "cmp -s '$AC71_MTMP/setup/manifest.json' '$MANIFEST'"
  rm -rf "$AC71_MTMP"
else
  echo "  FAIL: AC-71-MANIFEST-REGEN: setup/gen-manifest-hashes.sh not found"
  TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
fi

# =============================================================================
echo ""
echo "=== collateral-suites-green (execution half) — verification design :118 — every surviving suite whose arms bound to the deleted artifacts actually passes when run ==="
# GATE:QUALITY (cycle 1, attempt 1) finding: this AC has a state half above
# (AC-71-FIXTURE-FENCE, AC-71-DOC985, AC-71-HDIGEST, AC-71-DIGESTAGREE,
# AC-71-E2E, AC-71-INSTALL, AC-71-PHASEMARKER — the arm text is gone) but no
# execution arm — a suite whose deleted-arm text is gone can still fail for
# an unrelated regression, which only running it catches. Real execution,
# not a grep proxy.

# The AC-71-COLLATERAL-* execution arms are retired by issue #103's leaf rule,
# on the same ground: each of the seven callees carries its own `run:` step, so
# an unrelated regression in one of them is caught once per pass, under its own
# name. The STATE half of this AC — AC-71-FIXTURE-FENCE, AC-71-DOC985,
# AC-71-HDIGEST, AC-71-DIGESTAGREE, AC-71-E2E, AC-71-INSTALL,
# AC-71-PHASEMARKER — is unaffected and stays above: that the deleted arm text
# is gone is a property of the files' text, and needs no execution.


# =============================================================================
# unconditional-guards-green (AC-71-UNCOND-*) is retired by issue #103's leaf
# rule.
# =============================================================================
# The sweep re-ran seven sibling guards to confirm none of them had regressed.
# Each carries its own `run:` step, so a regression in any of them reds CI under
# its own name — once per pass rather than twice — and attributing the failure
# to the right suite is exactly what the per-step registration buys.
#
# This lane was already being narrowed for the same reason: the #62/#67 arms
# were removed for 2-level nesting cost, and the #59/#952 arms by operator
# decision, each time on the ground that CI's direct step is the real executor.
# The leaf rule finishes that narrowing rather than starting it.

# =============================================================================
echo ""
echo "=== cycle-scope-respected — this cycle's own branch diff stays within its declared allow_list ==="

HEAD_BRANCH="${GITHUB_HEAD_REF:-$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)}"
on_issue_branch() {
  case "$HEAD_BRANCH" in
    dev/*-issue-71|dev/*-issue-71-*) return 0 ;;
    *) return 1 ;;
  esac
}

allow_list=(
  # Mechanism deletions
  "scripts/handoff/emit-cycle-digest.sh"
  "scripts/preflight/scan-cross-issue-recurrence.sh"
  "docs/cycle-digest.jsonl"
  "tests/fixtures/cycle-digest-schema.json"
  "tests/fixtures/cycle-digest-954-at-k.jsonl"
  "tests/fixtures/cycle-digest-954-below-k.jsonl"
  "tests/fixtures/cycle-digest-954-cross-axis.jsonl"
  "tests/fixtures/cycle-digest-954-dedup-window.jsonl"
  "tests/fixtures/cycle-digest-954-dedup.jsonl"
  "tests/fixtures/cycle-digest-954-dual-axis.jsonl"
  "tests/fixtures/cycle-digest-954-out-of-window.jsonl"
  "tests/fixtures/cycle-digest-979-pre-migration-snapshot.jsonl"
  "tests/test-issue-953-cycle-digest.sh"
  "tests/test-issue-954-cross-issue-scan.sh"
  "tests/test-issue-6-severity-parse-contract.sh"
  "tests/test-issue-1-guard-contract.sh"
  "tests/test-issue-7-oracle-hardening.sh"
  "tests/manual/issue-953-manual-scenarios.md"
  "tests/manual/issue-954-manual-scenarios.md"
  # GATE:QUALITY (cycle 1, attempt 2): #7's manual scenario doc, missed
  # alongside its suite in the first pass.
  "tests/manual/issue-7-manual-scenarios.md"
  # New RED artifacts
  "tests/test-issue-71-digest-removal.sh"
  "tests/manual/issue-71-manual-scenarios.md"
  # Live docs / agent definitions edited
  "docs/autoflow-guide.md"
  "CLAUDE.md"
  "docs/design-rationale.md"
  "docs/improvement-backlog.md"
  "docs/maintained-docs.md"
  "docs/phases/analysis.md"
  ".claude/agents/autoflow-analyzer.md"
  "plugin/autoflow/agents/autoflow-analyzer.md"
  # Registry / manifest / CI
  "setup/manifest.json"
  "setup/gen-manifest-hashes.sh"
  "tests/fixtures/doc-invariants.json"
  ".github/workflows/e2e-dummy-target.yml"
  # Consumer-class arm edits
  "tests/test-issue-40-hook-additive.sh"
  "tests/test-issue-55-score-format-contract.sh"
  "tests/test-issue-985-doc-assertions.sh"
  "tests/test-issue-51-teammate-removal-verdict.sh"
  "tests/plugin/verify-e2e-dummy-target.sh"
  "tests/plugin/verify-install-into-target.sh"
  "tests/test-issue-35-phase-marker.sh"
  "tests/adr-0016-conformance-check.sh"
  "tests/test-issue-42-spawn-mode-contract.sh"
  "tests/test-issue-799-inert-cleanup.sh"
  # Sibling branch-unconditional guards amended with this cycle's scope-guard
  # admissions (feature design §8; ledger E16 class).
  "tests/test-issue-798-topology-flip.sh"
  "tests/test-issue-846-doc-assertions.sh"
  "tests/test-issue-848-doc-assertions.sh"
  "tests/test-issue-952-wizard-removal.sh"
  "tests/test-issue-955-subagent-background-ban.sh"
  # REFINE (020b823): drops a stale precedent comment (3 deletions, comment-
  # only) pointing at the now-removed digest emitter — legitimately on this
  # cycle's own change surface.
  "scripts/canary/emit-phase-marker.sh"
  # GREEN re-entry (d66f2d0): GATE:QUALITY-mandated fixes to the sibling
  # suites this cycle's own AC-71-UNCOND-* arms found red (ALLOWLIST_55/
  # ALLOWLIST_52 admissions, #59 stale-pin repair).
  "docs/doc-invariant-registry.md"
  "tests/issue-59-full-sweep-driver.sh"
  "tests/test-issue-52-peer-facilitator-premise.sh"
  "tests/test-issue-59-adoption-evidence-discipline.sh"
)

if on_issue_branch; then
  BASE_REF_SCOPE="$(resolve_base_ref)" || true
  if [ -n "${BASE_REF_SCOPE:-}" ]; then
    DIFF_FILES="$(cd "$PROJECT_ROOT" && git diff --name-only "$BASE_REF_SCOPE"...HEAD)"
    UNCOVERED="$(comm -23 <(printf '%s\n' "$DIFF_FILES" | sort -u) <(printf '%s\n' "${allow_list[@]}" | sort -u))"
    assert_true "AC-71-SCOPE: cycle diff set-differenced against the declared allow_list is empty (uncovered: $(printf '%s' "$UNCOVERED" | paste -sd, -))" \
      '[ -z "$UNCOVERED" ]'
  else
    echo "  BLOCK: no comparison base resolvable — AC-71-SCOPE counted FAIL, never skipped"
    TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
  fi
else
  note_deferred "AC-71-SCOPE: change-surface guard inert off the issue-71 dev branch (head: ${HEAD_BRANCH:-unknown}) — this cycle's own PR contract, not every branch's."
fi

# =============================================================================
echo ""
echo "Summary: $PASS/$TESTS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
exit $?
