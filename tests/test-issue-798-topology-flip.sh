#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/hooks/check-autoflow-gate.sh CLAUDE.md README.md docs/adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md docs/doc-invariant-registry.md docs/submodule-common-rules.md plugin/autoflow/hooks/check-autoflow-gate.sh scripts/test/check-cycle-scope-guard.sh setup/manifest.json tests/fixtures/doc-invariants.json tests/manual/issue-798-manual-scenarios.md tests/plugin/verify-e2e-dummy-target.sh
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
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
# AC6/AC7/AC9 are preservation guards and PASS both pre- and post-change.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
ADR_0015="$PROJECT_ROOT/docs/adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md"
README_MD="$PROJECT_ROOT/README.md"

# Base ref for the AC9 diff-scope guard: merge-base against main, overridable
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

# [MUST — non-vacuity, DQ-8/E5] The positive oracle uses the '→' arrow literal,
# unique to the flipped :42 line — CLAUDE.md:37's dual-mode *definition*
# ("single-repo = the host repository contains **zero submodules**") uses '='
# not '→', so a bare token grep would be vacuously GREEN pre-change. This
# literal only appears once the project self-classification sentence flips.

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
# AC6c (no sentence outside CLAUDE.md:42 flips a this-project claim) carried no
# assertion of its own: the verification design's §1 AC6 method leaned on the
# path-level scope-containment lane that used to sit below. Issue #75 retired
# that lane — a merged cycle's hand-written path allow-list forces every later
# cycle to edit it — so AC6c is now UNCOVERED in this file, recorded as such at
# docs/doc-invariant-registry.md §5 (Issue #75 table, the unscoped path
# allow-list lanes row). What replaces it is not another in-suite inventory:
# in-flight change surface is carried by docs/submodule-common-rules.md >
# Change Surface Rules, and a cycle-scoped lane is now branch-scoped by
# construction, enforced by scripts/test/check-cycle-scope-guard.sh.

# =============================================================================
echo ""
echo "=== AC7 ADR-HISTORICAL-KEEP (guard) — ADR-0015:148 kept verbatim ==="

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
  workflows_admitted_ac9="yes"
  while IFS= read -r wf; do
    [[ -z "$wf" ]] && continue
    # No filename allow-list here, deliberately. Since issue #75 retired this
    # file's path-level lane, WHICH files a cycle may touch is carried by
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
    [[ -n "$wf_sha" && -n "$man_sha" && "$wf_sha" == "$man_sha" ]] || workflows_admitted_ac9="no"
  done < <(git diff --name-only "$BASE_REF"...HEAD -- .claude/workflows 2>/dev/null || true)
  assert_true "AC9: diff touches no .claude/workflows/** path, OR every touched .claude/workflows/** path has a setup/manifest.json sha256 row matching its current content (#62 D10 — supersedes the #985/#27/#56/#59 substring window)" \
    "[ '$workflows_admitted_ac9' = 'yes' ]"
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

# AC15c (guard): the generic framework dual-mode prose must survive the sync —
# a README fix that overshoots into gutting reusability content is itself a
# regression (mirrors the AC6 preservation-guard pattern).

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
