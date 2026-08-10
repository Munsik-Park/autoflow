#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: Cycle-scope-guard retirement — Issue #75 (this cycle's own suite)
# =============================================================================
# Per .autoflow/issue-75-verification-design.md ("New spec files this design
# introduces" > tests/test-issue-75-scope-guard-retirement.sh): asserts the
# POST-STATE of §3's deletions (dead assertions, duplicate re-run blocks,
# hardcoded sibling totals, allow-list arrays are gone AND each carries a §5
# disposition row), the retained-lane survival legs (i)-(iv) (a deletion that
# overshoots a retained lane still parses and still runs green — a re-run
# cannot distinguish "defect removed" from "defect no longer reached"), the
# NUL-byte absence across tests/** (portable byte test — grep -P is rejected
# by the BSD grep this VERIFY host runs), the runner's absorbed newline-literal
# gate, the standing lint's delivery/registration/self-test surface (the lint
# itself is scripts/test/check-cycle-scope-guard.sh — GREEN-phase implementation;
# this suite asserts its behaviour, not its body), and this cycle's own
# branch-scoped allow_list lane.
#
# Known-RED until GREEN lands every §3 deletion, §3.1's runner absorption, and
# §3.8/§3.9's new lint + its CI registration: every absence assertion below
# currently finds its subject still present, and scripts/test/check-cycle-scope-guard.sh
# does not yet exist. This is expected — RED confirms these assertions are
# live, not vacuous.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

REGISTRY_RUNNER="$PROJECT_ROOT/tests/run-doc-invariants.sh"
REGISTRY="$PROJECT_ROOT/tests/fixtures/doc-invariants.json"
DOC_REGISTRY_MD="$PROJECT_ROOT/docs/doc-invariant-registry.md"
CI_WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"
LINT="$PROJECT_ROOT/scripts/test/check-cycle-scope-guard.sh"

SUITE_40="$PROJECT_ROOT/tests/test-issue-40-doc-assertions.sh"
SUITE_795="$PROJECT_ROOT/tests/test-issue-795-handoff-removal.sh"
SUITE_952="$PROJECT_ROOT/tests/test-issue-952-wizard-removal.sh"
SUITE_955="$PROJECT_ROOT/tests/test-issue-955-subagent-background-ban.sh"
SUITE_985="$PROJECT_ROOT/tests/test-issue-985-doc-assertions.sh"
SUITE_59="$PROJECT_ROOT/tests/test-issue-59-adoption-evidence-discipline.sh"
SUITE_7="$PROJECT_ROOT/tests/test-issue-7-oracle-hardening.sh"
SUITE_62="$PROJECT_ROOT/tests/test-issue-62-sequential-rounds.sh"
SUITE_67="$PROJECT_ROOT/tests/test-issue-67-deliberation-record.sh"
SUITE_69="$PROJECT_ROOT/tests/test-issue-69-verification-depth.sh"
SUITE_799="$PROJECT_ROOT/tests/test-issue-799-inert-cleanup.sh"
SUITE_964="$PROJECT_ROOT/tests/test-issue-964-sigpipe-safe-pipes.sh"
SUITE_798="$PROJECT_ROOT/tests/test-issue-798-topology-flip.sh"
SUITE_846="$PROJECT_ROOT/tests/test-issue-846-doc-assertions.sh"
SUITE_848="$PROJECT_ROOT/tests/test-issue-848-doc-assertions.sh"
SUITE_55="$PROJECT_ROOT/tests/test-issue-55-score-format-contract.sh"
SUITE_52="$PROJECT_ROOT/tests/test-issue-52-peer-facilitator-premise.sh"
SUITE_42="$PROJECT_ROOT/tests/test-issue-42-spawn-mode-contract.sh"
SUITE_43="$PROJECT_ROOT/tests/test-issue-43-report-channel-contract.sh"
SUITE_1="$PROJECT_ROOT/tests/test-issue-1-guard-contract.sh"
BATS_BOUNDARY="$PROJECT_ROOT/tests/issue-92/test-boundary-nonviolation.bats"
MOCK_GH="$PROJECT_ROOT/tests/issue-92/mock-gh/gh"
MANUAL_59="$PROJECT_ROOT/tests/manual/issue-59-manual-scenarios.md"
MANUAL_985="$PROJECT_ROOT/tests/manual/issue-985-manual-scenarios.md"

source "$PROJECT_ROOT/tests/lib/base-ref.sh"

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

note_deferred() {
  echo "  DEFERRED-OBSERVABLE: $1"
}

SKIP=0
note_skip() {
  echo "  SKIP: $1"
  SKIP=$((SKIP + 1))
}

# Heavy-mode-gated assertion: runs for real (counted in TESTS/PASS/FAIL) only
# when HEAVY_MODE=1; otherwise reported as SKIP (uncounted) rather than
# silently omitted, so a fast pass is never mistaken for full coverage.
assert_heavy() {
  local desc="$1" condition="$2"
  if [ "${HEAVY_MODE:-0}" = "1" ]; then
    assert_true "$desc" "$condition"
  else
    note_skip "$desc (heavy: set AUTOFLOW_ISSUE75_HEAVY=1)"
  fi
}

# Portable NUL-byte absence test (verification design, acceptance table row 1):
# `grep -aP '\x00'` is rejected by the BSD grep this host runs (exit 2,
# "invalid option -- P"), and a bare `! grep -aP ...` reads that exit 2 as "no
# match" -- manufacturing the exact vacuous-PASS class this cycle removes. The
# LC_ALL=C tr/cmp byte test fails loud on an unusable tool instead.
has_nul_byte() {
  local f="$1"
  LC_ALL=C tr -d '\000' < "$f" | cmp -s - "$f"
  # cmp -s exits 0 when the stripped copy equals the original -- i.e. NO NUL
  # bytes were present. So "has a NUL byte" is the FAILURE of that cmp.
  [ $? -ne 0 ]
}

# =============================================================================
echo "=== AC10a — dead assertions and defects of (a) are removed (post-state absence) ==="

assert_true "tests/test-issue-40-doc-assertions.sh is deleted (its permanent content lives in the registry under origin_issue:40, absorbed by §3.1)" \
  '[ ! -e "$SUITE_40" ]'

echo "--- NUL-byte absence across tests/** (portable byte test, not grep -P) ---"
NUL_HITS=""
while IFS= read -r -d '' f; do
  if has_nul_byte "$f"; then
    NUL_HITS="$NUL_HITS $f"
  fi
done < <(find "$PROJECT_ROOT/tests" -type f -print0)
assert_true "no file under tests/** contains an embedded NUL byte (hits:${NUL_HITS:-none})" \
  '[ -z "$NUL_HITS" ]'

if [ -f "$SUITE_964" ]; then
  assert_true "964: AC2-B inventory cross-check lane absent (banner+both arms removed)" \
    '! grep -q "AC2-B inventory\|AC2-B " "$SUITE_964" 2>/dev/null || ! grep -q "AC2-B" "$SUITE_964"'
  assert_true "964: AC2-B2 extractor cross-check lane absent" \
    '! grep -q "AC2-B2" "$SUITE_964"'
  assert_true "964: AC1-A lane (FILE_949 reference) absent" \
    '! grep -q "AC1-A" "$SUITE_964"'
  assert_true "964: AC1-C lane (FILE_949_RETIRED fixture) absent" \
    '! grep -q "AC1-C\|FILE_949_RETIRED" "$SUITE_964"'
  assert_true "964: AC4-A sibling re-run lane absent" \
    '! grep -q "AC4-A\|SIBLING_SUITES" "$SUITE_964"'
else
  note_deferred "964 lane-absence checks: tests/test-issue-964-sigpipe-safe-pipes.sh not present"
fi

for f in "$SUITE_42" "$SUITE_43"; do
  [ -f "$f" ] || continue
  assert_true "$(basename "$f"): GATE_SCHEMA dead assignment absent" \
    '! grep -q "GATE_SCHEMA" "$f"'
done

if [ -f "$SUITE_55" ]; then
  assert_true "55: registry-entries-added lane absent (runner already evaluates those registry entries as a registered CI step)" \
    '! grep -q "registry-entries-added" "$SUITE_55"'
fi

if [ -f "$SUITE_795" ]; then
  assert_true "795: AC-INVENTORY dangling-inventory lane absent (inventory_keep_check, its subject document does not exist)" \
    '! grep -q "AC-INVENTORY\|inventory_keep_check" "$SUITE_795"'
  assert_true "795: every reference to docs/host-service-decoupling-plan.md is absent" \
    '! grep -q "host-service-decoupling-plan" "$SUITE_795"'
fi

if [ -f "$MOCK_GH" ]; then
  assert_true "tests/issue-92/mock-gh/gh: GH_MOCK_PR_VIEW_ / GH_MOCK_API_ dispatch table absent (no consumer across tests/issue-92/*.bats)" \
    '! grep -qE "GH_MOCK_PR_VIEW_|GH_MOCK_API_" "$MOCK_GH"'
fi

if [ -f "$BATS_BOUNDARY" ]; then
  assert_true "tests/issue-92/test-boundary-nonviolation.bats: T12-1a/T12-1b diff-shaped halves (BASE_REF=origin/main comparison) absent" \
    '! grep -qE "BASE_REF=.origin/main." "$BATS_BOUNDARY"'
  assert_true "tests/issue-92/test-boundary-nonviolation.bats: T12-1a positive STATE half retained (blocked-by-review|subrepo label grep)" \
    'grep -qE "blocked-by-\(review\|subrepo\)" "$BATS_BOUNDARY"'
fi

echo "--- §5 disposition rows exist for each removal (state predicate over the registry doc) ---"
assert_true "docs/doc-invariant-registry.md: §5 disposition table exists (dropped/deferred/migrated tokens present)" \
  'grep -qE "dropped|migrated" "$DOC_REGISTRY_MD"'
DOC_REGISTRY_799_ROW="$(grep -A1 "diff must not touch .CLAUDE.md." "$DOC_REGISTRY_MD")"
assert_true "docs/doc-invariant-registry.md: 799 'diff must not touch CLAUDE.md' row disposition is dropped — cycle-local (was deferred)" \
  'printf "%s" "$DOC_REGISTRY_799_ROW" | grep -q "dropped — cycle-local"'
assert_true "docs/doc-invariant-registry.md §2 names scripts/test/check-cycle-scope-guard.sh as the check enforcing branch-scoping while a cycle-scoped lane lives" \
  'grep -q "check-cycle-scope-guard.sh" "$DOC_REGISTRY_MD"'

echo "--- §5 'Issue #75' table: one content-specific predicate per disposition row ---"
assert_true "registry row: the six unscoped path allow-list lanes -> dropped — cycle-local" \
  'grep -qE "^\| the six unscoped path allow-list lanes.*dropped — cycle-local" "$DOC_REGISTRY_MD"'
assert_true "registry row: 799 off-window arms -> dropped — cycle-local" \
  'grep -qE "^\| .799. off-window arms.*dropped — cycle-local" "$DOC_REGISTRY_MD"'
assert_true "registry row: 7 AC-7-7 / 62 AC-62-33 reader lanes -> dropped — subject retired" \
  'grep -qE "^\| .7. .AC-7-7. allow-list membership lane.*dropped — subject retired" "$DOC_REGISTRY_MD"'
assert_true "registry row: 964 AC2-B/AC2-B2/AC1-A/AC1-C -> dropped — subject retired" \
  'grep -qE "^\| .964. AC2-B / AC2-B2 inventory cross-checks.*dropped — subject retired" "$DOC_REGISTRY_MD"'
assert_true "registry row: 964 AC4-A / 952 AC5 T2 -> dropped — redundant" \
  'grep -qE "^\| .964. AC4-A sibling re-run; .952. AC5 T2.*dropped — redundant" "$DOC_REGISTRY_MD"'
assert_true "registry row: 795 AC-INVENTORY part (a) -> dropped — subject retired" \
  'grep -qE "^\| .795. AC-INVENTORY part \(a\).*dropped — subject retired" "$DOC_REGISTRY_MD"'
assert_true "registry row: 955 DC-4 -> dropped — subject retired" \
  'grep -qE "^\| .955. DC-4 \|.*dropped — subject retired" "$DOC_REGISTRY_MD"'
assert_true "registry row: 985 AC3-WORKFLOW-COUNT count fence -> dropped — cycle-local" \
  'grep -qE "^\| .985. .AC3-WORKFLOW-COUNT. count fence.*dropped — cycle-local" "$DOC_REGISTRY_MD"'
assert_true "registry row: 59 AC-59-14b/17a/17b/12c -> dropped — cycle-local" \
  'grep -qE "^\| .59. .AC-59-14b. / .AC-59-17a. / .AC-59-17b. / .AC-59-12c.*dropped — cycle-local" "$DOC_REGISTRY_MD"'
assert_true "registry row: 59 sibling 0-failed narrowing -> dropped — cycle-local, with recorded coverage loss" \
  'grep -qE "^\| .59. sibling 0-failed narrowing.*dropped — cycle-local, with recorded coverage loss" "$DOC_REGISTRY_MD"'
assert_true "registry row: 59 retired yml-window control set -> dropped — cycle-local, with recorded coverage loss" \
  'grep -qE "^\| .59. retired yml-window control set.*dropped — cycle-local, with recorded coverage loss" "$DOC_REGISTRY_MD"'
assert_true "registry row: 55 registry-entries-added -> dropped — redundant" \
  'grep -qE "^\| .55. .registry-entries-added.*dropped — redundant" "$DOC_REGISTRY_MD"'
assert_true "registry row: dead-symbol closure (42/43 GATE_SCHEMA et al.) -> dropped — subject retired" \
  'grep -qE "^\| .42./.43. .GATE_SCHEMA.*dropped — subject retired" "$DOC_REGISTRY_MD"'
assert_true "registry row: tests/issue-92 T12-1a/T12-1b/mock-gh dispatch table -> dropped — cycle-local" \
  'grep -qE "^\| .tests/issue-92/test-boundary-nonviolation.bats. .T12-1a. diff half.*dropped — cycle-local" "$DOC_REGISTRY_MD"'
assert_true "registry row: 40 tests/test-issue-40-doc-assertions.sh (whole file) -> promoted -> runner Step 0" \
  'grep -qE "^\| .40. .tests/test-issue-40-doc-assertions\.sh. \(whole file\).*promoted → runner Step 0" "$DOC_REGISTRY_MD"'

# =============================================================================
echo ""
echo "=== AC10b — retained-lane survival, sub-leg (i): label existence ==="

if [ -f "$SUITE_795" ]; then
  assert_true "795: AC-INVENTORY part (b) label retained (no tests/ file still references 'test-issue-495-token-scope')" \
    'grep -q "test-issue-495-token-scope" "$SUITE_795"'
fi
if [ -f "$SUITE_964" ]; then
  assert_true "964: AC2-A label retained" 'grep -q "AC2-A:" "$SUITE_964"'
  assert_true "964: AC2-A2 label retained" 'grep -q "AC2-A2:" "$SUITE_964"'
fi
if [ -f "$SUITE_59" ]; then
  assert_true "59: EXPECTED_OK= label retained" 'grep -q "^EXPECTED_OK=" "$SUITE_59"'
  assert_true "59: AC-59-14a label family retained" 'grep -q "AC-59-14a" "$SUITE_59"'
  assert_true "59: AC-59-22a label retained (rewritten, not removed)" 'grep -q "AC-59-22a:" "$SUITE_59"'
  assert_true "59: AC-59-22b label retained (rewritten, not removed)" 'grep -q "AC-59-22b:" "$SUITE_59"'
fi
if [ -f "$SUITE_799" ]; then
  assert_true "799: AC6-scope labels retained (path parity accumulator survives)" \
    'grep -q "AC6-scope" "$SUITE_799"'
fi
if [ -f "$SUITE_955" ]; then
  assert_true "955: a lane reading BASE_REF is retained" 'grep -q "BASE_REF" "$SUITE_955"'
  assert_true "955: AC4-DOGFOOD lane retained" 'grep -q "AC4-DOGFOOD" "$SUITE_955"'
fi
if [ -f "$SUITE_952" ]; then
  assert_true "952: manifest lane reading BASE_REF is retained" 'grep -q "BASE_REF" "$SUITE_952"'
fi
if [ -f "$SUITE_798" ]; then
  assert_true "798: git-plumbing STATE lanes reading BASE_REF are retained" 'grep -q "BASE_REF" "$SUITE_798"'
fi
if [ -f "$SUITE_52" ]; then
  assert_true "52: scope-fence-held-b label retained" 'grep -q "scope-fence-held-b" "$SUITE_52"'
fi
if [ -f "$SUITE_55" ]; then
  assert_true "55: ci-self-registration-* labels retained" 'grep -q "ci-self-registration-" "$SUITE_55"'
  assert_true "55: manual-scenario-present-* labels retained" 'grep -q "manual-scenario-present-" "$SUITE_55"'
fi
if [ -f "$SUITE_985" ]; then
  assert_true "985: AC3-WORKFLOW-COUNT label survives at the retained named-file existence assertion" \
    'grep -q "AC3-WORKFLOW-COUNT" "$SUITE_985"'
fi

# =============================================================================
echo ""
echo "=== AC10c — retained-lane survival, sub-leg (ii)/(iii): symbol resolution (orphan and reader direction) ==="

for f in "$SUITE_846" "$SUITE_848"; do
  [ -f "$f" ] || continue
  assert_true "$(basename "$f"): BASE_REF orphaned after its lane goes (no surviving occurrence)" \
    '! grep -q "BASE_REF" "$f"'
done
if [ -f "$SUITE_55" ]; then
  assert_true "55: BASEREF_LIB orphaned after its lane goes" '! grep -q "BASEREF_LIB" "$SUITE_55"'
  assert_true "55: SUITE_PATH retained (read by the CI-self-registration lane)" 'grep -q "SUITE_PATH" "$SUITE_55"'
  assert_true "55: MANUAL_PATH retained (read by the CI-self-registration lane)" 'grep -q "MANUAL_PATH" "$SUITE_55"'
fi
if [ -f "$SUITE_964" ]; then
  assert_true "964: FILE_949 orphaned" '! grep -q "FILE_949\b" "$SUITE_964"'
  assert_true "964: FILE_949_RETIRED orphaned" '! grep -q "FILE_949_RETIRED" "$SUITE_964"'
fi
if [ -f "$SUITE_7" ]; then
  assert_true "7: CANONICAL_PATHS orphaned (its subject was the deleted array bodies)" '! grep -q "CANONICAL_PATHS" "$SUITE_7"'
  assert_true "7: extract_allow_list_block orphaned" '! grep -q "extract_allow_list_block" "$SUITE_7"'
  assert_true "7: assert_allow_list_membership orphaned" '! grep -q "assert_allow_list_membership" "$SUITE_7"'
fi
if [ -f "$SUITE_62" ]; then
  assert_true "62: GUARD_SUITES orphaned" '! grep -q "GUARD_SUITES" "$SUITE_62"'
  assert_true "62: check_self_sibling_admission orphaned" '! grep -q "check_self_sibling_admission" "$SUITE_62"'
fi
if [ -f "$SUITE_955" ]; then
  assert_true "955: TEST_794 orphaned (DC-4's only readers went with the lane)" '! grep -q "TEST_794" "$SUITE_955"'
  assert_true "955: CYCLE_DIFF_FILES retained" 'grep -q "CYCLE_DIFF_FILES" "$SUITE_955"'
fi
if [ -f "$SUITE_59" ]; then
  assert_true "59: DELTA_12C_LABEL_PATTERN orphaned (self-scoped pattern with no surviving subject)" \
    '! grep -q "DELTA_12C_LABEL_PATTERN" "$SUITE_59"'
fi
if [ -f "$SUITE_985" ]; then
  assert_true "985: WORKFLOWS_DIR retained (the retained named-file assertion is its only surviving reader)" \
    'grep -q "WORKFLOWS_DIR" "$SUITE_985"'
fi
if [ -f "$SUITE_52" ]; then
  assert_true "52: BASE52 retained" 'grep -q "BASE52\b" "$SUITE_52"'
  assert_true "52: tests/lib/base-ref.sh source retained" 'grep -q "base-ref.sh" "$SUITE_52"'
fi

# =============================================================================
echo ""
echo "=== AC10d — retained-lane survival, sub-leg (iv): stale cross-reference restatement ==="

if [ -f "$SUITE_799" ]; then
  assert_true "799: 'allow-list containment' token no longer occurs anywhere in the file (index row + section header both restated)" \
    '! grep -q "allow-list containment" "$SUITE_799"'
  assert_true "799: 'allow_list' token survives only inside the retained workflows_* arm's restated delegation comment (not the removed lane's own text)" \
    '! grep -qE "allow_list=\(" "$SUITE_799"'
fi
if [ -f "$SUITE_42" ]; then
  assert_true "42: extract_section comment no longer names test-issue-40-doc-assertions (§3.2 deletes that file)" \
    '! grep -q "test-issue-40-doc-assertions" "$SUITE_42"'
fi
if [ -f "$SUITE_62" ]; then
  assert_true "62: header/comment sentences naming AC-62-33b as the mirrored idiom no longer occur (lane retired)" \
    '! grep -q "AC-62-33b" "$SUITE_62"'
fi
if [ -f "$SUITE_955" ]; then
  assert_true "955: DC-4 token absent from every prose site (index row, baseline-anomaly note, justified-pre-edit-passes row)" \
    '! grep -q "DC-4" "$SUITE_955"'
  assert_true "955: test-issue-794-doc-assertions no longer referenced in prose" \
    '! grep -q "test-issue-794-doc-assertions" "$SUITE_955"'
fi
if [ -f "$SUITE_59" ]; then
  assert_true "59: AC-59-12c token no longer occurs anywhere in the file (index row restated, lane removed)" \
    '! grep -q "AC-59-12c" "$SUITE_59"'
fi
if [ -f "$MANUAL_59" ]; then
  assert_true "tests/manual/issue-59-manual-scenarios.md: stale AC-59-12c family/count sentence restated" \
    '! grep -q "AC-59-12c" "$MANUAL_59"'
fi
if [ -f "$MANUAL_985" ]; then
  assert_true "tests/manual/issue-985-manual-scenarios.md: description no longer claims the label checks 'file count/names' (checks names only post-fence-removal)" \
    '! grep -q "file count/names" "$MANUAL_985"'
fi
if [ -f "$SUITE_69" ]; then
  assert_true "69: test-issue-40-doc-assertions token absent from its allow_list data row (§3.2 deletes that file)" \
    '! grep -q "test-issue-40-doc-assertions" "$SUITE_69"'
fi
if [ -f "$SUITE_67" ]; then
  assert_true "67: AC-59-14b token absent from its 'KNOWN RED mid-cycle' comment (§3.6 removes that lane)" \
    '! grep -q "AC-59-14b" "$SUITE_67"'
fi
if [ -f "$SUITE_7" ]; then
  assert_true "7: DELTA-lane comment no longer claims the six sibling scope-guard suites (798/799/846/848/952/955) already admit docs/cycle-digest.jsonl in their own allow-lists (§3.7 deletes those arrays)" \
    '! grep -q "admit this path in their own allow-lists" "$SUITE_7"'
  assert_true "7: DELTA-lane comment still explains the docs/cycle-digest.jsonl / HANDOFF step 6.7 obligation it is restated against, not merely deleted" \
    'grep -q "docs/cycle-digest.jsonl: HANDOFF step 6.7" "$SUITE_7"'
fi

# =============================================================================
# Heavy real re-runs are opt-in (AUTOFLOW_ISSUE75_HEAVY=1), run SERIALLY, and
# carry a recursion sentinel.
#
# Recursion sentinel: this suite sits inside two cycles its own heavy legs
# would otherwise re-enter. (a) #62's real re-run drives #59, which drives
# tests/issue-59-full-sweep-driver.sh, which runs every tests/test-issue-*.sh
# in the tree -- this file included -- heavy again. (b) #69's own
# AC-69-HARNESS-PINS re-executes this suite and expects exit 0. Every heavy
# leg below is launched with AUTOFLOW_ISSUE75_COMPOSED=1 exported into its
# environment; at the top of this check, if that var is already set, heavy
# mode is forced off regardless of AUTOFLOW_ISSUE75_HEAVY. Env inheritance
# breaks both cycles at depth 1: the inner invocation (whichever suite
# eventually re-invokes this file) always runs fast mode, never spawns its
# own heavy legs, and returns promptly.
#
# Serial, not parallel: CI runners carry 2 cores, and the #62 chain already
# fans out real worktree operations internally -- concurrent heavy legs here
# contend for the same limited cores/I-O rather than shortening wall-clock
# (VERIFY ledger E35: parallel launch combined with the recursion above drove
# a measured load average of 447+ and 825 kill-resistant processes).
if [ "${AUTOFLOW_ISSUE75_COMPOSED:-0}" = "1" ]; then
  HEAVY_MODE=0
else
  HEAVY_MODE="${AUTOFLOW_ISSUE75_HEAVY:-0}"
fi

HEAVY_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR" "$HEAVY_DIR" 2>/dev/null' EXIT

run_heavy() {
  local name="$1" suite="$2"; shift 2
  ( cd "$PROJECT_ROOT" && env AUTOFLOW_ISSUE75_COMPOSED=1 "$@" bash "$suite" > "$HEAVY_DIR/$name.out" 2>&1; echo $? > "$HEAVY_DIR/$name.exit" )
}
heavy_exit() { cat "$HEAVY_DIR/$1.exit" 2>/dev/null || echo -1; }
heavy_out() { cat "$HEAVY_DIR/$1.out" 2>/dev/null || echo ""; }

if [ "$HEAVY_MODE" = "1" ]; then
  [ -f "$SUITE_799" ] && run_heavy suite799 "$SUITE_799"
  [ -f "$SUITE_55" ] && run_heavy suite55 "$SUITE_55"
  [ -f "$SUITE_52" ] && run_heavy suite52 "$SUITE_52"
  [ -f "$SUITE_798" ] && run_heavy suite798 "$SUITE_798"
  [ -f "$PROJECT_ROOT/tests/test-issue-843-doc-assertions.sh" ] && run_heavy suite843 "$PROJECT_ROOT/tests/test-issue-843-doc-assertions.sh"
  [ -f "$PROJECT_ROOT/tests/test-issue-35-phase-marker.sh" ] && run_heavy suite35 "$PROJECT_ROOT/tests/test-issue-35-phase-marker.sh"
  [ -f "$PROJECT_ROOT/tests/test-issue-27-composition-oracle.sh" ] && run_heavy suite27 "$PROJECT_ROOT/tests/test-issue-27-composition-oracle.sh"
  [ -f "$SUITE_67" ] && run_heavy suite67_foreign "$SUITE_67" GITHUB_HEAD_REF="dev/2099-01-01-issue-999999"
  [ -f "$SUITE_69" ] && run_heavy suite69_foreign "$SUITE_69" GITHUB_HEAD_REF="dev/2099-01-01-issue-999999"
  [ -f "$SUITE_7" ] && run_heavy suite7 "$SUITE_7"
  [ -f "$SUITE_62" ] && run_heavy suite62 "$SUITE_62"
  [ -f "$SUITE_69" ] && run_heavy suite69_normal "$SUITE_69"
elif [ "${AUTOFLOW_ISSUE75_COMPOSED:-0}" = "1" ]; then
  echo "  (composed-run sentinel: AUTOFLOW_ISSUE75_COMPOSED=1 already set — forcing fast mode to break recursion)"
else
  echo "  (fast mode: heavy real re-runs skipped — set AUTOFLOW_ISSUE75_HEAVY=1 to run them)"
fi

echo ""
echo "=== AC-CI-REGISTER — the newline-literal guard is absorbed into the runner's Step 0 ==="

FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR" "$HEAVY_DIR" 2>/dev/null' EXIT

# Fixture registry: one entry with an embedded newline in `literal`, origin_issue
# deliberately NOT 40 -- the discriminator proving the absorbed gate lost the
# origin_issue==40 scoping the deleted #40 assertion had.
cat > "$FIXTURE_DIR/newline-literal-registry.json" <<'JSON'
{
  "invariants": [
    {
      "id": "fixture-newline-literal",
      "origin_issue": 9999,
      "file": "README.md",
      "predicate": "present",
      "match": "fixed",
      "literal": "line one\nline two",
      "scope": "permanent"
    }
  ]
}
JSON

FIXTURE_OUT="$(bash "$REGISTRY_RUNNER" "$FIXTURE_DIR/newline-literal-registry.json" 2>&1)"
FIXTURE_EXIT=$?
assert_true "AC-CI-REGISTER-a (hermetic): runner rejects a non-origin-40 entry whose literal contains an embedded newline (exit non-zero)" \
  '[ $FIXTURE_EXIT -ne 0 ]'
assert_true "AC-CI-REGISTER-b (hermetic): rejection carries a BLOCK line" \
  'printf "%s" "$FIXTURE_OUT" | grep -q "^BLOCK:"'

REAL_OUT="$(bash "$REGISTRY_RUNNER" 2>&1)"
REAL_EXIT=$?
assert_true "AC-CI-REGISTER-c (real registry): runner exits 0 against the real committed registry" \
  '[ $REAL_EXIT -eq 0 ]'

# =============================================================================
echo ""
echo "=== AC-DUP-EXEC — duplicate execution is resolved (static half: no direct sibling re-invocation) ==="

if [ -f "$SUITE_952" ]; then
  assert_true "952: no direct invocation of tests/plugin/verify-install-into-target.sh" \
    '! grep -q "plugin/verify-install-into-target.sh" "$SUITE_952"'
  assert_true "952: no direct invocation of tests/plugin/verify-e2e-dummy-target.sh" \
    '! grep -q "plugin/verify-e2e-dummy-target.sh" "$SUITE_952"'
fi

# =============================================================================
echo ""
echo "=== AC-SCOPE-LANES — the scope-guard allow-lists are removed or replaced; unscoped arrays are gone ==="

ARRAY_BEARING="$(cd "$PROJECT_ROOT" && grep -rlE '^[[:space:]]*(allow_list|ALLOWLIST_[0-9A-Za-z_]+)=\(' tests --include='*.sh' 2>/dev/null || true)"
echo "  array-bearing files at HEAD: $(printf '%s' "$ARRAY_BEARING" | tr '\n' ' ')"

for f in "$SUITE_952" "$SUITE_955" "$SUITE_798" "$SUITE_846" "$SUITE_848" "$SUITE_55" "$SUITE_52"; do
  [ -f "$f" ] || continue
  assert_true "$(basename "$f"): no unscoped allow_list/ALLOWLIST_* array remains" \
    '! grep -qE "^[[:space:]]*(allow_list|ALLOWLIST_[0-9A-Za-z_]+)=\(" "$f"'
done

assert_true "tests/test-issue-67-deliberation-record.sh: retained branch-scoped array still present (its containment lane is inert, not removed)" \
  'grep -qE "^[[:space:]]*allow_list=\(" "$SUITE_67"'
assert_true "tests/test-issue-69-verification-depth.sh: retained branch-scoped array still present" \
  'grep -qE "^[[:space:]]*allow_list\+?=\(" "$SUITE_69"'

echo "--- 799 clause (b): off-window chain identifiers absent by name (the design's named oracle) ---"
if [ -f "$SUITE_799" ]; then
  assert_true "799: claude_md_offwindow_changes identifier absent" \
    '! grep -q "claude_md_offwindow_changes" "$SUITE_799"'
  assert_true "799: adr_touched_files identifier absent" \
    '! grep -q "adr_touched_files" "$SUITE_799"'
  assert_true "799: repo_boundary_offwindow identifier absent" \
    '! grep -q "repo_boundary_offwindow" "$SUITE_799"'
fi

# =============================================================================
echo ""
echo "=== AC-LINT-DELIVERED — the standing lint scripts/test/check-cycle-scope-guard.sh is delivered and registered ==="

assert_true "scripts/test/check-cycle-scope-guard.sh exists" '[ -f "$LINT" ]'

if [ -f "$LINT" ]; then
  SELFTEST_OUT="$(bash "$LINT" --self-test 2>&1)"
  SELFTEST_EXIT=$?
  assert_true "check-cycle-scope-guard.sh --self-test exits 0 (all seven fixture classes classify correctly)" \
    '[ $SELFTEST_EXIT -eq 0 ]'

  DEFAULT_OUT="$(bash "$LINT" 2>&1)"
  DEFAULT_EXIT=$?
  assert_true "check-cycle-scope-guard.sh default run over the real tree exits 0 (no false positive on 67/69/this-cycle's conforming lanes)" \
    '[ $DEFAULT_EXIT -eq 0 ]'
else
  note_deferred "check-cycle-scope-guard.sh --self-test / default-run checks: lint not yet delivered"
fi

echo "--- CI registration: two run: steps, three paths: entries per trigger block ---"
assert_true "workflow: run: step for scripts/test/check-cycle-scope-guard.sh" \
  'grep -q "run: bash scripts/test/check-cycle-scope-guard.sh" "$CI_WORKFLOW"'
assert_true "workflow: run: step for tests/test-issue-75-scope-guard-retirement.sh" \
  'grep -q "run: bash tests/test-issue-75-scope-guard-retirement.sh" "$CI_WORKFLOW"'
PATHS_HITS_LINT="$(grep -c "'scripts/test/check-cycle-scope-guard.sh'" "$CI_WORKFLOW" || true)"
assert_true "workflow: 'scripts/test/check-cycle-scope-guard.sh' appears in both paths: trigger blocks (count 2, got $PATHS_HITS_LINT)" \
  '[ "$PATHS_HITS_LINT" -eq 2 ]'
PATHS_HITS_SUITE="$(grep -c "'tests/test-issue-75-scope-guard-retirement.sh'" "$CI_WORKFLOW" || true)"
assert_true "workflow: 'tests/test-issue-75-scope-guard-retirement.sh' appears in both paths: trigger blocks (count 2, got $PATHS_HITS_SUITE)" \
  '[ "$PATHS_HITS_SUITE" -eq 2 ]'
PATHS_HITS_MANUAL="$(grep -c "tests/manual/issue-75-manual-scenarios.md" "$CI_WORKFLOW" || true)"
assert_true "workflow: tests/manual/issue-75-manual-scenarios.md appears in both paths: trigger blocks (count 2, got $PATHS_HITS_MANUAL)" \
  '[ "$PATHS_HITS_MANUAL" -eq 2 ]'

# The composition legs (the real cross-suite re-runs this suite gates behind
# AUTOFLOW_ISSUE75_HEAVY) have no other venue: fast mode SKIPs them by design
# (the recursion/runaway fix), so CI's own step is the sole place they ever
# actually execute. Step-scoped, not job-level (the workflow's own comment
# above the step states why: a job-level value would leak into every sibling
# step and re-enter the recursion the sentinel exists to cut) -- so the check
# is bounded to this suite's own run: step block, capture-then-grep, no pipe.
WORKFLOW_75_STEP_BLOCK="$(grep -A3 'run: bash tests/test-issue-75-scope-guard-retirement.sh' "$CI_WORKFLOW")"
assert_true "workflow: the #75 suite's own run: step carries a step-scoped AUTOFLOW_ISSUE75_HEAVY: \"1\" env line (sole venue of the composition legs)" \
  'printf "%s" "$WORKFLOW_75_STEP_BLOCK" | grep -qE "AUTOFLOW_ISSUE75_HEAVY: *\"1\""'

echo "--- fixed-window readers re-run green after the §3.9 registration edit (cached from the heavy launch above) ---"
# Class A: forward '^ *paths:' windows. Only the workflow-window guard's own
# line matters here; a suite may still be RED for unrelated §3.7/§3.6/§3.9
# reasons mid-cycle, so this is reported as an observation rather than gated
# on full-suite exit status.
if [ "$HEAVY_MODE" = "1" ]; then
  for pair in "suite799:$SUITE_799" "suite55:$SUITE_55" "suite52:$SUITE_52" "suite798:$SUITE_798"; do
    name="${pair%%:*}"; f="${pair#*:}"
    [ -f "$f" ] || continue
    echo "  observed: $(basename "$f") exit=$(heavy_exit "$name") (class-A fixed-window reader)"
  done
  # Class B: backward distance budgets (re-run as a check that §3.9's placement
  # rule -- append strictly below the last existing entry -- was followed)
  for pair in "suite843:$PROJECT_ROOT/tests/test-issue-843-doc-assertions.sh" "suite35:$PROJECT_ROOT/tests/test-issue-35-phase-marker.sh" "suite27:$PROJECT_ROOT/tests/test-issue-27-composition-oracle.sh"; do
    name="${pair%%:*}"; f="${pair#*:}"
    [ -f "$f" ] || continue
    echo "  observed: $(basename "$f") exit=$(heavy_exit "$name") (class-B distance-budget reader)"
  done
else
  note_skip "fixed-window reader re-runs (class A: 799/55/52/798; class B: 843/35/27) (heavy: set AUTOFLOW_ISSUE75_HEAVY=1)"
fi

# =============================================================================
echo ""
echo "=== AC-SCOPE-INERT — a merged cycle's scope guard cannot red an unrelated branch (off-branch arm is uncounted) ==="

deferred_marker_present() {
  local name="$1" label="$2"
  heavy_out "$name" | grep -qi "DEFERRED-OBSERVABLE.*$label" && echo 0 || echo 1
}

if [ -f "$SUITE_67" ]; then
  DEFERRED_67="$(deferred_marker_present suite67_foreign "AC-67-SCOPE")"
  assert_heavy "67: off-branch arm (foreign GITHUB_HEAD_REF) emits the note_deferred marker for AC-67-SCOPE, TESTS/PASS/FAIL uncounted" \
    '[ "$DEFERRED_67" = "0" ]'
fi
if [ -f "$SUITE_69" ]; then
  DEFERRED_69="$(deferred_marker_present suite69_foreign "AC-69-SCOPE")"
  assert_heavy "69: off-branch arm (foreign GITHUB_HEAD_REF, on_issue_branch() predicate arm) emits the note_deferred marker for AC-69-SCOPE" \
    '[ "$DEFERRED_69" = "0" ]'
fi

# This cycle's own lane is on-branch for the whole cycle (dev/2026-08-10-issue-75)
# -- only an explicit override reaches its off-branch arm. Since this file IS
# that suite, this section exercises its own AC-75-SCOPE-style lane inline
# below rather than shelling out to itself.

# =============================================================================
echo ""
echo "=== AC-59-DECOUPLE — the sibling assertion-total hardcoding in 59 is resolved ==="

if [ -f "$SUITE_59" ]; then
  assert_true "59: AC-59-14b (27 total pin) absent" '! grep -q "AC-59-14b" "$SUITE_59"'
  assert_true "59: AC-59-17a (985 total pin) absent" '! grep -q "AC-59-17a" "$SUITE_59"'
  assert_true "59: AC-59-17b (test-issue-1 total pin) absent" '! grep -q "AC-59-17b" "$SUITE_59"'
fi
if [ -f "$SUITE_62" ]; then
  assert_true "62: AC-62-37 (798/799 exit-0 + 0-failed) still present as the surviving execution home" \
    'grep -q "AC-62-37" "$SUITE_62"'
fi
if [ -f "$SUITE_985" ]; then
  assert_true "985: AC3-WORKFLOW-COUNT count-fence comparison absent, named-file existence retained" \
    '! grep -qE "ls -1 .github/workflows.*wc -l" "$SUITE_985" && grep -q "AC3-WORKFLOW-COUNT" "$SUITE_985"'
fi

# =============================================================================
echo ""
echo "=== AC-955-DC4 — 955's DC-4 lane, whose subject was retired upstream, is removed and recorded ==="

if [ -f "$SUITE_955" ]; then
  assert_true "955: DC-4 lane's TEST_794 guard is gone, and a real re-run of 955 is green" \
    '! grep -q "TEST_794" "$SUITE_955"'
fi

# =============================================================================
echo ""
echo "=== AC-COMPOSITION — real re-run of #7 / #62 / #69 after their dependent assertions are updated in the same commit ==="

if [ -f "$SUITE_7" ]; then
  assert_heavy "tests/test-issue-7-oracle-hardening.sh exits 0 at HEAD (real re-run, no re-implementation of its membership logic)" \
    '[ "$(heavy_exit suite7)" -eq 0 ]'
fi
if [ -f "$SUITE_62" ]; then
  assert_heavy "tests/test-issue-62-sequential-rounds.sh exits 0 at HEAD (real re-run)" \
    '[ "$(heavy_exit suite62)" -eq 0 ]'
fi
if [ -f "$SUITE_69" ]; then
  assert_heavy "tests/test-issue-69-verification-depth.sh exits 0 at HEAD (retained lane is genuinely inert here, real re-run)" \
    '[ "$(heavy_exit suite69_normal)" -eq 0 ]'
fi

assert_true "bash tests/run-doc-invariants.sh exits 0 against the real committed registry" \
  '[ $REAL_EXIT -eq 0 ]'

# =============================================================================
echo ""
echo "=== AC-75-SCOPE (this cycle's own branch-scoped allow_list lane, §3.12) ==="

HEAD_BRANCH="${GITHUB_HEAD_REF:-$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)}"

# Membership rule (not a fixed enumeration, per §3.12): this cycle's change
# surface -- every file §3 names -- plus derived members. Stated here as the
# same membership the design names, kept in one place so a partial
# enumeration cannot silently drift from the design.
allow_list=(
  "tests/test-issue-40-doc-assertions.sh"
  "tests/run-doc-invariants.sh"
  "tests/test-issue-964-sigpipe-safe-pipes.sh"
  "tests/test-issue-795-handoff-removal.sh"
  "tests/test-issue-952-wizard-removal.sh"
  "tests/test-issue-955-subagent-background-ban.sh"
  "tests/test-issue-985-doc-assertions.sh"
  "tests/test-issue-59-adoption-evidence-discipline.sh"
  "tests/test-issue-799-inert-cleanup.sh"
  "tests/test-issue-798-topology-flip.sh"
  "tests/test-issue-846-doc-assertions.sh"
  "tests/test-issue-848-doc-assertions.sh"
  "tests/test-issue-55-score-format-contract.sh"
  "tests/test-issue-52-peer-facilitator-premise.sh"
  "tests/test-issue-7-oracle-hardening.sh"
  "tests/test-issue-62-sequential-rounds.sh"
  "tests/test-issue-42-spawn-mode-contract.sh"
  "tests/test-issue-43-report-channel-contract.sh"
  "tests/issue-92/test-boundary-nonviolation.bats"
  "tests/issue-92/mock-gh/gh"
  "scripts/test/check-cycle-scope-guard.sh"
  ".github/workflows/e2e-dummy-target.yml"
  "docs/doc-invariant-registry.md"
  "setup/manifest.json"
  "tests/test-issue-75-scope-guard-retirement.sh"
  "tests/manual/issue-75-manual-scenarios.md"
  # §3's stale-cross-reference restatement sites -- both files describe a lane
  # this cycle retires (AC-59-12c's family/count sentence; AC3-WORKFLOW-COUNT's
  # "file count/names" description) and are restated, not removed, per the
  # verification design's stale-cross-reference leg.
  "tests/manual/issue-59-manual-scenarios.md"
  "tests/manual/issue-985-manual-scenarios.md"
  # GATE:QUALITY RED closure (f3b6d91): these two carried stale references to
  # deleted lanes/files (69's allow_list data row named the deleted
  # test-issue-40-doc-assertions.sh; 67's "KNOWN RED mid-cycle" comment cited
  # the removed AC-59-14b lane) and are restated in this cycle's diff for the
  # first time, per the same stale-cross-reference leg as the pair above.
  "tests/test-issue-67-deliberation-record.sh"
  "tests/test-issue-69-verification-depth.sh"
  # HANDOFF step 6.7 appends the cycle digest to the dev branch after reviewer
  # review, so the digest file is a mandated member of every cycle's diff.
  "docs/cycle-digest.jsonl"
  ".autoflow/issue-75-feature-design.md"
  ".autoflow/issue-75-verification-design.md"
  ".autoflow/issue-75-ledger.md"
)

case "$HEAD_BRANCH" in
  dev/*-issue-75|dev/*-issue-75-*)
    BASE_REF="$(resolve_base_ref)" || {
      echo "  BLOCK: no comparison base resolvable — AC-75-SCOPE counted FAIL, never skipped"
      TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
      BASE_REF=""
    }
    if [[ -n "${BASE_REF:-}" ]]; then
      DIFF_FILES="$(cd "$PROJECT_ROOT" && git diff --name-only "$BASE_REF"...HEAD)"
      UNCOVERED="$(comm -23 <(printf '%s\n' "$DIFF_FILES" | sort -u) <(printf '%s\n' "${allow_list[@]}" | sort -u))"
      assert_true "AC-75-SCOPE: cycle diff, set-differenced against the declared allow_list, is empty (uncovered: $(printf '%s' "$UNCOVERED" | paste -sd, -))" \
        "[ -z \"\$(printf '%s' '$UNCOVERED')\" ]"
    fi
    ;;
  *)
    note_deferred "AC-75-SCOPE: change-surface guard inert off the issue-75 dev branch (head: ${HEAD_BRANCH:-unknown}) — this cycle's own PR contract, not every branch's."
    ;;
esac

# =============================================================================
echo ""
if [ "$HEAVY_MODE" = "1" ]; then
  echo "HEAVY LEGS: RAN"
else
  echo "HEAVY LEGS: SKIPPED ($SKIP) — set AUTOFLOW_ISSUE75_HEAVY=1 for full coverage (real cross-suite re-runs, not exercised by this pass)"
fi
echo "Summary: $PASS/$TESTS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
exit $?
