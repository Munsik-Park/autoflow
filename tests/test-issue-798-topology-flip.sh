#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: submodule-detach topology-flip RED/GREEN harness — Issue #798
# ([#785-S11a] 토폴로지 플립)
# =============================================================================
# Tier-1 scripted assertion suite per verification design
# (.autoflow/issue-798-verification-design.md). Docs+config change (no jest,
# no npm) — mirrors tests/test-issue-795-handoff-removal.sh /
# tests/test-issue-797-doc-invocation.sh: assert_true/assert_false over
# git-plumbing + grep.
#
# [MUST] Git-plumbing, not filesystem. Every detach assertion queries
# HEAD/the index (`git ls-tree`, `git ls-files -s`, `git config --file
# .gitmodules`), never a working-tree filesystem probe — `git rm --cached
# services` leaves `services/` on disk as an untracked local checkout, and a
# CI fresh clone has no `services/` at all. Filesystem probes would give
# environment-sensitive, non-reproducible RED/GREEN (verification design §0
# / R1).
#
# Scope (verification design §1/§2):
#   AC1  GITMODULES-CLEAR   — .gitmodules absent from HEAD (D-1 = delete)
#   AC2  GITLINK-CLEAR      — no 160000 gitlink at `services` in HEAD/index
#   AC3  COUNT-ZERO         — non-vacuity keystone: submodule count == 0
#   AC5  DOC-CLAUDE-CLASS   — CLAUDE.md:42 self-classification flipped
#   AC6  DOC-SECONDARY-COHERENCE (guard) — dual-mode definitions + Secondary
#        markers preserved
#   AC7  ADR-HISTORICAL-KEEP (guard) — ADR-0015:148 kept verbatim
#   AC9  NO-NEW-TIMING (guard)      — no new hook/workflow timing mechanism
#   AC10 SCOPE-CONTAINMENT (guard) — diff ⊆ the enumerated flip-caused set
#   AC12 CI-ENFORCED        — the suite + `.gitmodules` are CI-registered
#   AC15 README-SYNC        — README.md dangling submodule references removed
#        (GATE:QUALITY E11 remediation, ledger E11): no --recurse-submodules
#        clone instruction, no structure-tree `(git submodule)` entry; the
#        generic framework dual-mode prose (line 76) is a preserved guard.
#
# Not in this file (verification design §2/§5):
#   AC4  local .git/config + .git/modules residue        → tests/manual/issue-798-manual-scenarios.md
#   AC8  HANDOFF reclassification (behavioral)            → tests/manual/issue-798-manual-scenarios.md
#   AC11 host-purity DELTA regression (reuse, unchanged)  → tests/test-issue-788-host-purity-delta.sh
#   AC13 resync-submodules.sh clean run-through           → DEFERRED: verification design §2 item 4
#        states this is added "only after the D-2 guard lands" — the oracle
#        needs the script's empty-gm_names fix in place (D-2) before it can
#        assert exit-0 run-through instead of pipefail-abort. Adding it now
#        against the live (still-populated) .gitmodules would be vacuously
#        GREEN (today's script never reaches the empty-gm_names branch),
#        which is not a valid RED. Add at VERIFY once GREEN lands D-2.
#   AC14 purity-ratchet burn-down (reuse) — feature §5 confirms the
#        conditional is structurally unreachable for #798 (no baseline entry
#        references `services`); stays GREEN unconditionally via
#        tests/plugin/verify-e2e-dummy-target.sh E2a arm, no new assertion.
#
# RED expectation (pre-change): AC1/AC2/AC3/AC5(negative present + positive
# absent)/AC12 FAIL. AC3 COUNT-ZERO is the non-vacuity keystone — a
# pre-change PASS on any detach assertion means the test is mis-scoped.
# AC6/AC7/AC9/AC10 are preservation guards and PASS both pre- and post-change.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
ADR_0015="$PROJECT_ROOT/docs/adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md"
README_MD="$PROJECT_ROOT/README.md"

# Base ref for AC9/AC10 diff-scope guards: merge-base against main, overridable
# via env (precedent: #797 ISSUE_797_BASE_REF).
BASE_REF="${ISSUE_798_BASE_REF:-$(git -C "$PROJECT_ROOT" merge-base HEAD main 2>/dev/null || true)}"

PASS=0; FAIL=0; TESTS=0

# ---------------------------------------------------------------------------
# Helpers (assert_* pattern per tests/test-issue-788-host-purity-delta.sh)
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
echo "=== AC1 GITMODULES-CLEAR — .gitmodules absent from HEAD (D-1=delete) ==="
# Presence-first branch (D-1 settled = delete): absence of the blob at HEAD is
# the PASS condition. Never runs `git show HEAD:.gitmodules` unconditionally —
# under D-1 that errors "path does not exist in HEAD" and would abort a set -e
# suite (DQ-7). Defensive fallback only fires if a .gitmodules blob still
# exists at HEAD (pre-change today, or a future regression).
gitmodules_tree_entry="$(git ls-tree HEAD -- .gitmodules 2>/dev/null || true)"
if [[ -z "$gitmodules_tree_entry" ]]; then
  assert_true "AC1: .gitmodules absent from HEAD (git ls-tree empty)" "true"
else
  echo "  (defensive fallback: .gitmodules blob present at HEAD — checking for [submodule stanza)"
  assert_false "AC1 (fallback): no [submodule stanza in committed .gitmodules" \
    "git show HEAD:.gitmodules | grep -qE '^\\[submodule'"
fi

# =============================================================================
echo ""
echo "=== AC2 GITLINK-CLEAR — no gitlink at 'services' in committed tree ==="

assert_true "AC2a: git ls-tree HEAD -- services is empty" \
  "[ -z \"\$(git ls-tree HEAD -- services 2>/dev/null)\" ]"
assert_true "AC2b: git ls-files -s -- services has no 160000 mode row" \
  "! git ls-files -s -- services 2>/dev/null | grep -q '^160000'"

# =============================================================================
echo ""
echo "=== AC3 COUNT-ZERO — non-vacuity keystone: submodule count == 0 ==="

assert_true "AC3a: git submodule status is empty" \
  "[ -z \"\$(git submodule status 2>/dev/null)\" ]"
assert_true "AC3b: HEAD .gitmodules path-entry count == 0" \
  "[ \"\$(git show HEAD:.gitmodules 2>/dev/null | grep -cE '^\\[submodule' || true)\" -eq 0 ]"

# =============================================================================
echo ""
echo "=== AC5 DOC-CLAUDE-CLASS — CLAUDE.md project self-classification flipped ==="

assert_false "AC5-negative: old multi-repo self-classification sentence absent" \
  "grep -qF '1 submodule (\`services\`) → **multi-repo**' '$CLAUDE_MD'"
# [MUST — non-vacuity, DQ-8/E5] The positive oracle uses the '→' arrow literal,
# unique to the flipped :42 line — CLAUDE.md:37's dual-mode *definition*
# ("single-repo = the host repository contains **zero submodules**") uses '='
# not '→', so a bare token grep would be vacuously GREEN pre-change. This
# literal only appears once the project self-classification sentence flips.
assert_true "AC5-positive: '**zero submodules** → **single-repo**' present (non-vacuous arrow literal)" \
  "grep -qF '**zero submodules** → **single-repo**' '$CLAUDE_MD'"

# =============================================================================
echo ""
echo "=== AC6 DOC-SECONDARY-COHERENCE (guard) — dual-mode + Secondary markers preserved ==="
# [Harness fix — GATE:PLAN finding, ledger E10] The verification design's
# guard (a) literals ('single-repo = the host' / 'multi-repo =') were authored
# without CLAUDE.md's actual bold markers around the term itself
# ("**single-repo** = the host", not "single-repo = the host" — the '**'
# interrupts the naive substring). Corrected here to the literal marker-aware
# strings so the guard is GREEN pre-change as the design intends, rather than
# a false pre-change RED from a harness typo.

assert_true "AC6a: CLAUDE.md single-repo dual-mode definition present & unchanged" \
  "grep -qF 'single-repo** = the host' '$CLAUDE_MD'"
assert_true "AC6a: CLAUDE.md multi-repo dual-mode definition present & unchanged" \
  "grep -qF 'multi-repo** = the host' '$CLAUDE_MD'"

# AC6b: every *Secondary (multi-repo):* marker across docs/ (+ CLAUDE.md)
# unchanged — no diff hunk touches a line carrying the marker.
if [[ -z "$BASE_REF" ]]; then
  echo "  SKIP: AC6b (no base ref available)"
  TESTS=$((TESTS + 1))
else
  # #848 admission (same remedy class as the sibling allow-list re-admissions
  # above, deebfc3 precedent): #848's GATE:PLAN-passed design (ledger E11/E12)
  # promotes the DELIVER multi-repo fenced list to a purely ADDITIVE
  # '*Secondary (multi-repo):*' marker line (convention parity with HANDOFF
  # step 4 / CLAUDE.md). The #798 concern is unchanged for every other
  # marker: no pre-existing marker line may be removed or altered — only the
  # one approved #848 added line is filtered out of the diff scan.
  secondary_marker_diff="$(git diff "$BASE_REF"...HEAD -- docs/ CLAUDE.md 2>/dev/null \
    | grep -E '^[+-].*Secondary \(multi-repo\):' \
    | grep -vF '+*Secondary (multi-repo):* In a multi-repo deployment (one or more submodules), DELIVER fans out' || true)"
  assert_true "AC6b: no diff hunk touches a '*Secondary (multi-repo):*' marker line" \
    "[ -z '$secondary_marker_diff' ]"
fi
# AC6c (no sentence outside CLAUDE.md:42 flips a this-project claim) is
# covered by AC10 SCOPE-CONTAINMENT below — no separate assertion here
# (verification design §1 AC6 method).

# =============================================================================
echo ""
echo "=== AC7 ADR-HISTORICAL-KEEP (guard) — ADR-0015:148 kept verbatim ==="

assert_true "AC7a: ADR-0015 'remains a valid multi-repo' sentence present" \
  "grep -qF 'remains a valid multi-repo' '$ADR_0015'"
if [[ -n "$BASE_REF" ]]; then
  adr_diff="$(git diff "$BASE_REF"...HEAD -- "$ADR_0015" 2>/dev/null || true)"
  assert_true "AC7b: no diff hunk against ADR-0015 (immutable historical record)" \
    "[ -z '$adr_diff' ]"
fi

# =============================================================================
echo ""
echo "=== AC9 NO-NEW-TIMING (guard) — no new hook/workflow timing mechanism ==="

if [[ -z "$BASE_REF" ]]; then
  echo "  SKIP: AC9 (no base ref available)"
  TESTS=$((TESTS + 1))
else
  diff_files_ac9="$(git diff --name-only "$BASE_REF"...HEAD 2>/dev/null || true)"
  # #843 parity-carried exception: the topology-flip work itself must not add
  # a new hook, but an in-flight #843 engine-hook change (the FIRST intentional
  # edit to check-autoflow-gate.sh since #790 packaging) is admitted when it
  # lands together with a byte-identical plugin/autoflow/hooks mirror — the
  # same shape as verify-package.sh AC5 parity / test-788 AC10a. A hook diff
  # that is NOT the #843 gate-script change (or lacks mirror parity) still
  # fails this guard.
  hooks_touched_ac9="no"
  printf '%s\n' "$diff_files_ac9" | grep -q '^\.claude/hooks/' && hooks_touched_ac9="yes"
  hooks_admitted_ac9="no"
  if [[ "$hooks_touched_ac9" == "no" ]]; then
    hooks_admitted_ac9="yes"
  elif [[ "$diff_files_ac9" == *".claude/hooks/check-autoflow-gate.sh"* ]] \
    && cmp -s "$PROJECT_ROOT/.claude/hooks/check-autoflow-gate.sh" \
              "$PROJECT_ROOT/plugin/autoflow/hooks/check-autoflow-gate.sh" 2>/dev/null; then
    hooks_admitted_ac9="yes"
  fi
  assert_true "AC9: diff touches no .claude/hooks/** path, OR only check-autoflow-gate.sh with its plugin mirror byte-identical (#843 parity-carried exception)" \
    "[ '$hooks_admitted_ac9' = 'yes' ]"
  assert_false "AC9: diff touches no .claude/workflows/** path" \
    "printf '%s\n' \"\$diff_files_ac9\" | grep -q '^\\.claude/workflows/'"
fi

# =============================================================================
echo ""
echo "=== AC10 SCOPE-CONTAINMENT (guard) — diff ⊆ enumerated flip-caused set ==="
# Allow-list = verification design §1 AC10 / feature §2 committed surface
# (ledger E2). Exactly one of the two candidate CI workflow homes may appear.

if [[ -z "$BASE_REF" ]]; then
  echo "  SKIP: AC10 (no base ref available)"
  TESTS=$((TESTS + 1))
else
  diff_files_ac10="$(git diff --name-only "$BASE_REF"...HEAD 2>/dev/null || true)"
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
    ".gitmodules"
    "services"
    "CLAUDE.md"
    "README.md"
    "setup/manifest.json"
    "scripts/resync-submodules.sh"
    ".github/workflows/e2e-dummy-target.yml"
    ".github/workflows/topology-flip.yml"
    "tests/test-issue-798-topology-flip.sh"
    "tests/manual/issue-798-manual-scenarios.md"
    # #964 (SIGPIPE-safe assertion pipes): sibling cycle files — the 13-line
    # guard transform touches 798/799/800/949/955 in place (no filename
    # change), the Testing Standards doc addition, and the new RED suite
    # (cc8030d precedent).
    "docs/submodule-common-rules.md"
    "tests/test-issue-799-inert-cleanup.sh"
    "tests/test-issue-800-doc-assertions.sh"
    "tests/test-issue-949-manifest-regen-doc.sh"
    "tests/test-issue-955-subagent-background-ban.sh"
    "tests/test-issue-964-sigpipe-safe-pipes.sh"
    # Reciprocal registration: 16ebab9 added #964 cycle files to 952's own
    # G1 allow-list, pulling the 952 suite into this cycle's diff.
    "tests/test-issue-952-wizard-removal.sh"
    # #846 sibling-fix pass: review-triage hardening RED suite lands on the
    # same branch (test/CI surface only; no #798 content touched).
    "tests/test-issue-846-doc-assertions.sh"
    "tests/manual/issue-846-manual-scenarios.md"
    # #846 sibling-fix pass, transitive: the other scope-guard tests' own
    # allow-lists were amended (this same pass) to re-admit the two #846
    # files above — those edits land in this diff too.
    "tests/test-issue-799-inert-cleanup.sh"
    "tests/test-issue-800-doc-assertions.sh"
    "tests/test-issue-949-manifest-regen-doc.sh"
    "tests/test-issue-952-wizard-removal.sh"
    # #848 transitive: sibling guard-admission edits (b8b9ad6) land on this branch
    "tests/test-issue-794-doc-assertions.sh"
    "tests/test-issue-795-handoff-removal.sh"
    "tests/test-issue-955-subagent-background-ban.sh"
    # #846 GREEN source surface (GATE:PLAN-passed design §2, commit f5d5539):
    # review-triage hardening edits these docs on the same branch; CLAUDE.md
    # and setup/manifest.json are already admitted above.
    ".codex/review.md"
    "docs/autoflow-guide.md"
    "docs/design-rationale.md"
    # #848 sibling-fix pass: the pointer-bump procedure + propagation-batching
    # RED suite + manual scenarios land on the same branch, and its GREEN
    # source surface (git-workflow.md / external-review-sequencing.md /
    # submodule-common-rules.md; autoflow-guide.md and CLAUDE.md already
    # admitted above) is edited on this branch too.
    "tests/test-issue-848-doc-assertions.sh"
    "tests/manual/issue-848-manual-scenarios.md"
    "docs/git-workflow.md"
    "docs/external-review-sequencing.md"
    "docs/submodule-common-rules.md"
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
    "tests/test-issue-799-inert-cleanup.sh"
    "tests/test-issue-800-doc-assertions.sh"
    "tests/test-issue-952-wizard-removal.sh"
    "tests/test-issue-955-subagent-background-ban.sh"
    # #951 (doc-invariant registry): sibling cycle files — the new registry
    # runner, hermetic base-ref resolver, registry data, lifecycle-rule doc,
    # RED suite + fixtures, and INDEX/maintained-docs routing land on the
    # same branch (df4641d/da11389/fa12eb1 precedent). #951 also DELETES
    # tests/test-issue-796-doc-assertions.sh and
    # tests/test-issue-797-doc-invocation.sh (794/800/949 already admitted
    # above); their permanent invariants migrate into the registry.
    "tests/test-issue-796-doc-assertions.sh"
    "tests/test-issue-797-doc-invocation.sh"
    "tests/test-issue-951-registry.sh"
    # Round-2 fix (VERIFY): the #951 cycle's RED/VERIFY pass also touches
    # these two sibling test files (795 AC-ORPHAN allow-list, adr-0016
    # AC-R3-c manifest-count guard, both re-anchored for #951's manifest-
    # closure/baseline consequences) — omitted from the round-1 registration
    # above.
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
    "docs/INDEX.md"
    "docs/maintained-docs.md"
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
    "docs/maintained-docs.md"
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
  done <<< "$diff_files_ac10"

  echo "  changed files: $(printf '%s' "$diff_files_ac10" | grep -c . || true)"
  if [[ -n "$disallowed" ]]; then
    echo "  disallowed:"
    printf '%s' "$disallowed" | sed 's/^/    /'
  fi
  assert_true "AC10: git diff --name-only ⊆ allow-list (no disallowed files)" \
    "[ -z '$disallowed' ]"
fi

# =============================================================================
echo ""
echo "=== AC12 CI-ENFORCED — the #798 suite is CI-registered ==="

ci_home=""
for wf in ".github/workflows/e2e-dummy-target.yml" ".github/workflows/topology-flip.yml"; do
  if [[ -f "$PROJECT_ROOT/$wf" ]] && grep -q 'test-issue-798-topology-flip' "$PROJECT_ROOT/$wf" 2>/dev/null; then
    ci_home="$wf"
    break
  fi
done

if [[ -n "$ci_home" ]]; then
  echo "  CI home: $ci_home"
  assert_true "AC12a: $ci_home references tests/test-issue-798-topology-flip.sh" "true"
  assert_true "AC12b: $ci_home paths: trigger lists .gitmodules" \
    "ctx=\$(grep -A5 '^ *paths:' '$PROJECT_ROOT/$ci_home'); printf '%s\n' \"\$ctx\" | grep -qF '.gitmodules'"
else
  assert_true "AC12a: some workflow references tests/test-issue-798-topology-flip.sh" "false"
  echo "  SKIP: AC12b (no CI home found yet)"
  TESTS=$((TESTS + 1))
fi

# =============================================================================
echo ""
echo "=== AC15 README-SYNC — README.md dangling submodule references removed ==="
# GATE:QUALITY E11 remediation (ledger E11): README.md:85-87 (Quick Start clone
# --recurse-submodules instruction) and README.md:127-128 (structure tree
# services/librechat submodule entry) are stale inbound references to the
# detached `services` submodule. Fixed-string oracles chosen to avoid
# false-positiving on the generic framework prose at README.md:76
# ("Multi-Sub-Repo Support ... single-repo is the degenerate case") or on doc
# filenames like docs/submodule-common-rules.md.

assert_false "AC15a: README has no --recurse-submodules clone instruction" \
  "grep -qF -- '--recurse-submodules' '$README_MD'"
assert_false "AC15b: README structure tree has no '(git submodule)' entry" \
  "grep -qF '(git submodule)' '$README_MD'"
# AC15c (guard): the generic framework dual-mode prose must survive the sync —
# a README fix that overshoots into gutting reusability content is itself a
# regression (mirrors the AC6 preservation-guard pattern).
assert_true "AC15c (guard): README generic 'single-repo is the degenerate case' prose preserved" \
  "grep -qF 'single-repo is the degenerate case' '$README_MD'"

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
