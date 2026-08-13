#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: unchanged-tree re-run -> tree-identity check — Issue #88 (cycle-scoped)
# =============================================================================
# Per the verification design (.autoflow/issue-88-verification-design.md), the
# permanent doc-invariant registry (tests/fixtures/doc-invariants.json,
# origin_issue: 88) carries the STATE literal pins for the shipped clauses.
# This suite carries what the registry structurally cannot: delta/allow-list
# containment (AC:untouched-fences), cross-file agreement (AC:register-write-
# authority, AC:carry-forward-anchor, AC:verify-claims-discharge, AC:inherited-
# not-passed, AC:contract-sync), and real-git / real-ledger oracles clause-
# bound to the shipped text (AC:capture-atomicity, AC:outcome-stability-fence,
# AC:mechanism-holds, AC:entry-grammar, AC:use-record, AC:registry-and-suites-
# green). See docs/doc-invariant-registry.md §1 for the two-lane rule this
# suite's DELTA/EXEC/JSON-shaped assertions are the cycle-scoped lane of.
#
# Retirement: this file is deleted, per its own disposition row (§9), in the
# final commit before the DELIVER push once this cycle's PR merges (§2) —
# alongside its run:/paths: registration in
# .github/workflows/contract-suites.yml, per the #73 precedent (ff68814).
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GUIDE="$PROJECT_ROOT/docs/autoflow-guide.md"
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
CONTRACTS="$PROJECT_ROOT/docs/teammate-contracts.md"
SUBMOD="$PROJECT_ROOT/docs/submodule-common-rules.md"
README="$PROJECT_ROOT/README.md"
REGISTRY_RUNNER="$PROJECT_ROOT/tests/run-doc-invariants.sh"
ARCHITECT_WF="$PROJECT_ROOT/.claude/workflows/architect-deliberation.js"

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

note_deferred() { echo "  DEFERRED-OBSERVABLE: $1"; }
skip_no_base() {
  local label="$1"
  echo "  SKIP: $label (no base ref available)"
  TESTS=$((TESTS + 1))
}

HEAD_BRANCH="${GITHUB_HEAD_REF:-$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)}"

# ---------------------------------------------------------------------------
# Runs body_fn inside a fresh scratch dir (removed afterward regardless of
# outcome), shared by the three real-git oracles below so each carries only
# its own git sequence, not the mktemp/subshell/cleanup wrapper around it.
# ---------------------------------------------------------------------------
run_in_scratch_dir() {   # <label> <body_fn>
  local label="$1" body_fn="$2" dir rc=0
  dir="$(mktemp -d "${TMPDIR:-/tmp}/issue88-${label}.XXXXXX")" || return 1
  ( set -e; cd "$dir"; "$body_fn" )
  rc=$?
  rm -rf "$dir" 2>/dev/null || true
  return $rc
}

# ---------------------------------------------------------------------------
# Section extractor (## heading -> body up to next ## heading), used for the
# clause-bound oracles below, mirroring tests/run-doc-invariants.sh's own
# extract_section but kept local so this suite has no runtime dependency on
# the runner internals.
# ---------------------------------------------------------------------------
extract_h2() {              # heading_text file
  local heading="$1" file="$2"
  awk -v h="$heading" '
    !f && /^## / { t=$0; sub(/^## /,"",t); sub(/[ \t]+$/,"",t); if (t==h) { f=1; next } }
    f { if (/^## /) { f=0; next } else print }
  ' "$file"
}

VERIFY_BODY="$(extract_h2 "VERIFY — Test Run + Verification" "$GUIDE")"
REFINE_BODY="$(extract_h2 "REFINE — Refactor (Green maintained)" "$GUIDE")"

# =============================================================================
echo "=== AC:mechanism-holds — real-git oracle, clause-bound to the shipped command pair ==="
# =============================================================================
# The clause extracted from VERIFY (§2.1 capture point) must name the same
# three commands the oracle drives. Pre-GREEN the clause does not exist yet,
# so the extraction below is empty and the case-match fails closed.
CLAUSE_CMD_STATUS="$(printf '%s' "$VERIFY_BODY" | grep -oF 'git status --porcelain' | head -1)"
CLAUSE_CMD_TREE="$(printf '%s' "$VERIFY_BODY" | grep -oF 'git rev-parse HEAD^{tree}' | head -1)"

clause_names_mechanism() {
  case "$CLAUSE_CMD_STATUS" in
    "git status --porcelain") : ;;
    *) return 1 ;;
  esac
  case "$CLAUSE_CMD_TREE" in
    "git rev-parse HEAD^{tree}") : ;;
    *) return 1 ;;
  esac
  return 0
}

mechanism_oracle_body() {
  git init -q
  git config user.email t@example.com
  git config user.name tester
  echo one > f.txt
  git add f.txt
  git commit -q -m init
  T0="$(git rev-parse HEAD^{tree})"
  # uncommitted tracked-file modification: hash unchanged, status dirty
  echo two >> f.txt
  T1="$(git rev-parse HEAD^{tree})"
  S1="$(git status --porcelain)"
  [ "$T0" = "$T1" ]
  [ -n "$S1" ]
  # committed modification: hash changes
  git add f.txt
  git commit -q -m change
  T2="$(git rev-parse HEAD^{tree})"
  [ "$T0" != "$T2" ]
}
mechanism_oracle() { run_in_scratch_dir "mechanism" mechanism_oracle_body; }

assert_true "AC:mechanism-holds: shipped clause names the documented command pair AND a real scratch repo demonstrates unchanged-tree / dirty-status / changed-tree over it" \
  "clause_names_mechanism && mechanism_oracle"

# =============================================================================
echo ""
echo "=== AC:capture-atomicity — clause-bound: status+tree+head fixed to one instant, dirty capture point suppresses the entry ==="
# =============================================================================
CLAUSE_CMD_HEAD="$(printf '%s' "$VERIFY_BODY" | grep -oF 'git rev-parse HEAD' | head -1)"
CLAUSE_IMMEDIATE="$(printf '%s' "$VERIFY_BODY" | grep -cF 'immediately before the suite is started' || true)"

clause_names_capture_point() {
  clause_names_mechanism || return 1
  case "$CLAUSE_CMD_HEAD" in
    "git rev-parse HEAD") : ;;
    *) return 1 ;;
  esac
  [ "$CLAUSE_IMMEDIATE" -ge 1 ]
}

capture_atomicity_oracle_body() {
  git init -q
  git config user.email t@example.com
  git config user.name tester
  echo one > f.txt
  git add f.txt
  git commit -q -m init
  # clean capture point: status empty, tree/head resolvable
  S_CLEAN="$(git status --porcelain)"
  [ -z "$S_CLEAN" ]
  # dirty a tracked file, observe at the (would-be) capture point
  echo two >> f.txt
  S_DIRTY="$(git status --porcelain)"
  [ -n "$S_DIRTY" ]
  # commit the change, observe again — the two capture-point observations differ
  git add f.txt
  git commit -q -m change
  S_AFTER="$(git status --porcelain)"
  [ "$S_DIRTY" != "$S_AFTER" ]
}
capture_atomicity_oracle() { run_in_scratch_dir "capture" capture_atomicity_oracle_body; }

assert_true "AC:capture-atomicity: shipped clause fixes status/tree/head to one instant immediately before the run AND a real scratch repo shows the dirty-vs-clean capture-point observations differ" \
  "clause_names_capture_point && capture_atomicity_oracle"

# =============================================================================
echo ""
echo "=== AC:outcome-stability-fence — clause-bound: base-ref-dependent state is named outside the inheritance guarantee ==="
# =============================================================================
CLAUSE_BASEREF_FENCE="$(printf '%s' "$VERIFY_BODY" | grep -cF 'base-ref-dependent assertions' || true)"
CLAUSE_REMOTE_FENCE="$(printf '%s' "$VERIFY_BODY" | grep -cF 'remote refs, network, clock, environment' || true)"

clause_names_outofscope_fence() {
  [ "$CLAUSE_BASEREF_FENCE" -ge 1 ] && [ "$CLAUSE_REMOTE_FENCE" -ge 1 ]
}

# Reproduces the live case §2.4 names: `resolve_base_ref`'s fallback is
# `git merge-base HEAD origin/main`, so a fetch that advances `origin/main`
# along the SAME line of history as HEAD (catching up to a commit HEAD
# already descends from) moves the resolved merge-base and therefore the
# computed diff, while HEAD's own tree never moves. Building `origin/main`
# as a branch that starts strictly behind HEAD and diverges (rather than
# advancing past HEAD) was the earlier defect: it made HEAD an ancestor of
# the advanced `origin/main`, pinning the merge-base at HEAD itself and the
# `...`-diff at empty regardless of the advance — undetectable by
# construction, not a demonstration of the clause.
outcome_stability_oracle_body() {
  git init -q -b main
  git config user.email t@example.com
  git config user.name tester
  echo base > base.txt;    git add base.txt;    git commit -q -m base     # C0
  echo shared > shared.txt; git add shared.txt;  git commit -q -m shared   # C1 (later "caught up to")
  echo devonly > devonly.txt; git add devonly.txt; git commit -q -m devonly # C2 == HEAD
  C0="$(git rev-parse HEAD~2)"
  C1="$(git rev-parse HEAD~1)"
  git branch origin/main "$C0"          # remote starts well behind HEAD

  T0="$(git rev-parse HEAD^{tree})"
  BASE0="$(resolve_base_ref)"
  DIFF0="$(git diff --name-only "$BASE0"...HEAD)"

  git branch -f origin/main "$C1"       # fetch advances origin/main -> C1 (still an ancestor of HEAD); HEAD/working tree untouched

  T1="$(git rev-parse HEAD^{tree})"
  BASE1="$(resolve_base_ref)"
  DIFF1="$(git diff --name-only "$BASE1"...HEAD)"

  [ "$T0" = "$T1" ]        # tree identity holds across the fetch
  [ "$BASE0" != "$BASE1" ] # the resolved base moved (C0 -> C1)
  [ "$DIFF0" != "$DIFF1" ] # ... so the base-relative diff moved too
}
outcome_stability_oracle() { run_in_scratch_dir "outcome" outcome_stability_oracle_body; }

assert_true "AC:outcome-stability-fence: shipped clause names base-ref-dependent / out-of-tree state as outside the inheritance guarantee AND a real scratch repo shows tree hash unchanged while a base-relative diff moves" \
  "clause_names_outofscope_fence && outcome_stability_oracle"

# =============================================================================
echo ""
echo "=== AC:entry-grammar / AC:use-record — real-ledger selection cases, clause-bound to the marker-scoped ordering rule ==="
# =============================================================================
CLAUSE_MARKER_SCOPED="$(printf '%s' "$VERIFY_BODY" | grep -cF 'marker-scoped and then positional' || true)"
CLAUSE_SKIPPED_BY_SCAN="$(printf '%s' "$VERIFY_BODY" | grep -cF 'skipped by the scan' || true)"
CLAUSE_NONCHAINING="$(printf '%s' "$VERIFY_BODY" | grep -cF 'never selectable by condition 2' || true)"

clause_names_selection_rule() {
  [ "$CLAUSE_MARKER_SCOPED" -ge 1 ] && [ "$CLAUSE_SKIPPED_BY_SCAN" -ge 1 ]
}
clause_names_nonchaining() {
  [ "$CLAUSE_NONCHAINING" -ge 1 ]
}

# select_green_tree_cycle <ledger_file> <cycle> — marker-scoped ("### green-tree | cycle: <C> |"),
# then positional (last matching heading wins, valid or not); a heading of
# any other marker is skipped by the scan, never selected-then-rejected. An
# entry whose field block is incomplete (missing tree/head/worktree/result/
# authority) is selected but yields NO printed tree — a mismatch, not a
# silent fall-back to an earlier good entry (docs/autoflow-guide.md > VERIFY
# > Green-tree register > Entry grammar, "An entry the marker-scoped scan
# selects whose field block is incomplete ... is not selected and yields a
# mismatch"). Prints the selected entry's "tree" field, or nothing on a
# mismatch (no selectable cycle-matching heading at all, or the last one
# incomplete).
select_green_tree_cycle() {
  local ledger="$1" cycle="$2"
  awk -v cyc="$cycle" '
    function finalize() {
      if (in_sel) {
        if (have_tree && have_head && have_worktree && have_result && have_authority) {
          sel_tree = c_tree; sel_valid = 1
        } else {
          sel_valid = 0
        }
      }
    }
    function reset_candidate() {
      c_tree=""; have_tree=0; have_head=0; have_worktree=0; have_result=0; have_authority=0
    }
    BEGIN { in_sel=0; sel_tree=""; sel_valid=0; reset_candidate() }
    /^### green-tree \| cycle: / {
      finalize()
      line=$0; sub(/^### green-tree \| cycle: /,"",line)
      split(line, parts, " | ")
      c=parts[1]
      in_sel = (c == cyc)
      reset_candidate()
      next
    }
    /^### / { finalize(); in_sel=0; next }
    in_sel && /^- tree: /      { t=$0; sub(/^- tree: /,"",t);      c_tree=t; have_tree=1 }
    in_sel && /^- head: /      { have_head=1 }
    in_sel && /^- worktree: /  { have_worktree=1 }
    in_sel && /^- result: /    { have_result=1 }
    in_sel && /^- authority: / { have_authority=1 }
    END { finalize(); if (sel_valid) print sel_tree; else print "" }
  ' "$ledger"
}

make_ledger_variant_a() {   # <path>
  cat > "$1" <<'LEDGER'
# Decision Ledger — issue #88 (fixture)

### green-tree | cycle: 1 | runner: VERIFY step 1
- tree: aaaa1111
- head: bbbb1111
- worktree: clean
- result: Tests: 10 passed, 10 total
- authority: Green-tree register

### green-tree | cycle: 2 | runner: VERIFY step 1
- tree: cccc2222
- head: dddd2222
- worktree: clean
- result: Tests: 12 passed, 12 total
- authority: Green-tree register
LEDGER
}

make_ledger_variant_b() {   # <path> — variant A + a malformed cycle-1 entry appended last
  make_ledger_variant_a "$1"
  cat >> "$1" <<'LEDGER'

### green-tree | cycle: 1 | runner: VERIFY step 1
- tree: eeee3333
LEDGER
}

make_ledger_use_record() { # <path> — variant A + a green-tree-use entry appended after cycle-1's green-tree
  cat > "$1" <<'LEDGER'
# Decision Ledger — issue #88 (fixture)

### green-tree | cycle: 1 | runner: VERIFY step 1
- tree: aaaa1111
- head: bbbb1111
- worktree: clean
- result: Tests: 10 passed, 10 total
- authority: Green-tree register

### green-tree-use | cycle: 1 | runner: REFINE step 2
- outcome: inherited
- mismatch-cause: none
- source: VERIFY step 1 cycle 1 | tree: aaaa1111 | head: bbbb1111 | result: Tests: 10 passed, 10 total
- authority: Green-tree register
LEDGER
}

FIX_DIR="$(mktemp -d "${TMPDIR:-/tmp}/issue88-ledger.XXXXXX")"
trap 'rm -rf "$FIX_DIR" 2>/dev/null || true' EXIT

make_ledger_variant_a "$FIX_DIR/variant-a.md"
make_ledger_variant_b "$FIX_DIR/variant-b.md"
make_ledger_use_record "$FIX_DIR/use-record.md"

SEL_A="$(select_green_tree_cycle "$FIX_DIR/variant-a.md" 1)"
SEL_B="$(select_green_tree_cycle "$FIX_DIR/variant-b.md" 1)"
SEL_USE="$(select_green_tree_cycle "$FIX_DIR/use-record.md" 1)"

# The three flags below are precomputed with a plain `[` test (never eval)
# so that only a controlled "0"/"1" literal — never the file/awk-derived
# SEL_* string itself — is interpolated into assert_true's eval'd condition
# (verification design > Method constraints carried into RED: no eval of
# file-derived content).
SEL_A_OK=0;   [ "$SEL_A" = "aaaa1111" ] && SEL_A_OK=1
SEL_B_OK=0;   [ -z "$SEL_B" ]           && SEL_B_OK=1
SEL_USE_OK=0; [ "$SEL_USE" = "aaaa1111" ] && SEL_USE_OK=1

assert_true "AC:entry-grammar variant A: current-cycle green-tree entry selected over a later different-cycle heading (clause-bound: guide states marker-scoped-then-positional selection) (got: '$SEL_A')" \
  "clause_names_selection_rule && [ \"$SEL_A_OK\" = \"1\" ]"

assert_true "AC:entry-grammar variant B: a malformed current-cycle entry (missing head/worktree/result/authority) appended last IS the marker-scoped-then-positional selection, and its incompleteness yields a mismatch — NOT a silent fall-back to the earlier good entry, so selection resolves to empty rather than to 'aaaa1111' (clause-bound) (got: '$SEL_B')" \
  "clause_names_selection_rule && [ \"$SEL_B_OK\" = \"1\" ]"

assert_true "AC:use-record non-chaining: a green-tree-use entry appended after the cycle's green-tree entry does not become the selection and does not force a mismatch — the green-tree entry is still selected (clause-bound: guide states the non-chaining rule) (got: '$SEL_USE')" \
  "clause_names_selection_rule && clause_names_nonchaining && [ \"$SEL_USE_OK\" = \"1\" ]"

# =============================================================================
echo ""
echo "=== Cross-file agreement checks (registry entries cannot compare two files) ==="
# =============================================================================

CLAUDE_LEDGER_BODY="$(extract_h2 "" "$CLAUDE_MD" 2>/dev/null)"  # unused placeholder to keep extractor style consistent
CLAUDE_HAS_GREEN_TREE="$(grep -cF 'green-tree' "$CLAUDE_MD" || true)"
CLAUDE_HAS_GREEN_TREE_USE="$(grep -cF 'green-tree-use' "$CLAUDE_MD" || true)"

assert_true "AC:register-write-authority: CLAUDE.md Decision Ledger writer list names the same green-tree / green-tree-use markers the guide's register block defines" \
  "[ \"$CLAUSE_MARKER_SCOPED\" -ge 1 ] && [ \"$CLAUDE_HAS_GREEN_TREE\" -ge 1 ] && [ \"$CLAUDE_HAS_GREEN_TREE_USE\" -ge 1 ]"

CONTRACTS_HOME="$(grep -cF 'issue-{N}-ledger.md' "$CONTRACTS" || true)"
GUIDE_HOME="$(printf '%s' "$VERIFY_BODY" | grep -cF 'issue-{N}-ledger.md' || true)"

assert_true "AC:carry-forward-anchor: the ledger home named in the VERIFY clause agrees with the home named in the contract mirror (both cite .autoflow/issue-{N}-ledger.md) — gated on the green-tree register block existing (the pre-existing verify-detection cross-reference alone must not vacuously pass this check)" \
  "[ \"$CLAUSE_MARKER_SCOPED\" -ge 1 ] && [ \"$GUIDE_HOME\" -ge 1 ] && [ \"$CONTRACTS_HOME\" -ge 1 ]"

CLAUDE_DISCHARGE="$(grep -cF 'discharges the test-summary re-run for that tree' "$CLAUDE_MD" || true)"
assert_true "AC:verify-claims-discharge: CLAUDE.md > Verify teammate claims names the same green-tree marker the guide's register block defines" \
  "[ \"$CLAUSE_MARKER_SCOPED\" -ge 1 ] && [ \"$CLAUDE_DISCHARGE\" -ge 1 ] && [ \"$CLAUDE_HAS_GREEN_TREE\" -ge 1 ]"

GUIDE_INHERITED="$(printf '%s' "$VERIFY_BODY" | grep -cF 'inherited' || true)"
CONTRACTS_INHERITED="$(grep -cF 'inherited' "$CONTRACTS" || true)"
SUBMOD_INHERITED="$(grep -cF 'inherited' "$SUBMOD" || true)"

assert_true "AC:inherited-not-passed: the 'inherited' reported word is carried consistently across the guide, the Test AI / Developer AI contract mirror, and Reporting Format" \
  "[ \"$GUIDE_INHERITED\" -ge 1 ] && [ \"$CONTRACTS_INHERITED\" -ge 1 ] && [ \"$SUBMOD_INHERITED\" -ge 1 ]"

CLAUDE_ROUTER_REFINE="$(grep -cF 'Test AI re-confirms Green' "$CLAUDE_MD" || true)"
CLAUDE_TABLE_REFINE="$(grep -cF 'refactor done + Green re-confirmed' "$CLAUDE_MD" || true)"
README_REFINE="$(grep -cF 'Green re-confirmation' "$README" || true)"
assert_true "AC:contract-sync (guard, NOT a RED discriminator per the G-REG idiom — this pin already holds pre-cycle): the router lines that say REFINE 're-confirms Green' / 'Green re-confirmed' / 'Green re-confirmation' survive untouched by this cycle's diff, so they remain true under inheritance (a step that inherits still re-confirms the Green state, fresh or cited)" \
  "[ \"$CLAUDE_ROUTER_REFINE\" -ge 1 ] && [ \"$CLAUDE_TABLE_REFINE\" -ge 1 ] && [ \"$README_REFINE\" -ge 1 ]"

# =============================================================================
echo ""
echo "=== AC:mismatch-cause-record — the cause literals sit inside the mismatch branch, not the match branch ==="
# =============================================================================
# Best-effort structural check: within the VERIFY body, the first occurrence
# of "Match" (the match-branch marker) must precede the first occurrence of
# "no-entry" (one of the three mismatch-cause literals) is FALSE — the cause
# literals belong to the Mismatch branch, so "Mismatch" must precede them.
MATCH_LINE="$(printf '%s\n' "$VERIFY_BODY" | grep -nF -- '- **Match**' | head -1 | cut -d: -f1)"
MISMATCH_LINE="$(printf '%s\n' "$VERIFY_BODY" | grep -nF -- '- **Mismatch**' | head -1 | cut -d: -f1)"
NOENTRY_LINE="$(printf '%s\n' "$VERIFY_BODY" | grep -nF 'no-entry' | head -1 | cut -d: -f1)"

assert_true "AC:mismatch-cause-record: the Mismatch branch marker precedes the first 'no-entry' cause literal (the record sits in the mismatch branch, not the match branch)" \
  "[ -n \"\${MISMATCH_LINE:-}\" ] && [ -n \"\${NOENTRY_LINE:-}\" ] && [ \"$MISMATCH_LINE\" -lt \"$NOENTRY_LINE\" ]"

# =============================================================================
echo ""
echo "=== AC:registry-and-suites-green — the permanent registry and the suites reading the touched documents stay green ==="
# =============================================================================
DOC_INV_OUT="$(cd "$PROJECT_ROOT" && bash "$REGISTRY_RUNNER" 2>&1)"
DOC_INV_EXIT=$?
assert_true "AC:registry-and-suites-green: tests/run-doc-invariants.sh (no argument, real registry) exits 0" \
  "[ $DOC_INV_EXIT -eq 0 ]"

for SIBLING in "test-issue-73-adr-status.sh" "test-issue-955-subagent-background-ban.sh"; do
  SIB_PATH="$PROJECT_ROOT/tests/$SIBLING"
  if [[ -f "$SIB_PATH" ]]; then
    OUT="$(cd "$PROJECT_ROOT" && bash "$SIB_PATH" 2>&1)"; RC=$?
    assert_true "AC:registry-and-suites-green: bash tests/$SIBLING exits 0 (KNOWN RISK — carried risk (1): the REFINE [MUST] re-aim may collide with this suite's literal pin; flagged in the RED report, not fixed here)" \
      "[ $RC -eq 0 ]"
  else
    note_deferred "AC:registry-and-suites-green: tests/$SIBLING not present — retired in an earlier cycle, nothing to re-run"
  fi
done

# =============================================================================
echo ""
echo "=== Composition oracle — setup/manifest.json rows for the four manifest-registered edited docs (guard; live only once the diff actually touches them) ==="
# =============================================================================
MANIFEST="$PROJECT_ROOT/setup/manifest.json"
for SRC in "CLAUDE.md" "docs/autoflow-guide.md" "docs/teammate-contracts.md" "docs/submodule-common-rules.md"; do
  ROW_COUNT="$(jq -r --arg s "$SRC" '[.artifacts[] | select(.source==$s)] | length' "$MANIFEST" 2>/dev/null || echo 0)"
  assert_true "composition-oracle (guard): setup/manifest.json carries exactly one artifacts[] row for $SRC" \
    "[ \"$ROW_COUNT\" = \"1\" ]"

  MANIFEST_SHA="$(jq -r --arg s "$SRC" '.artifacts[] | select(.source==$s) | .sha256' "$MANIFEST" 2>/dev/null)"
  CUR_SHA="$(shasum -a 256 "$PROJECT_ROOT/$SRC" | awk '{print $1}')"
  SHA_OK=0; [ "$MANIFEST_SHA" = "$CUR_SHA" ] && SHA_OK=1
  assert_true "composition-oracle: setup/manifest.json sha256 row for $SRC matches the live source (real set-intersection + shasum recomputation, verification design Composition-oracle determination row 1) (manifest: $MANIFEST_SHA, current: $CUR_SHA)" \
    "[ \"$SHA_OK\" = \"1\" ]"
done

# =============================================================================
echo ""
echo "=== Composition oracle — the two new ledger markers are outside the ARCHITECT seed rule's authority match AND outside HANDOFF's review-autofix count window ==="
# =============================================================================
SEED_RULE="$(grep -oF 'ARCHITECT mutual ACCEPT' "$ARCHITECT_WF" | head -1)"
REVIEW_AUTOFIX_MARKER="$(grep -cF 'review-autofix' "$GUIDE" || true)"

assert_true "composition-oracle: the ARCHITECT seed rule's authority match ('ARCHITECT mutual ACCEPT') is present in the workflow, and the ledger row's markers (green-tree / green-tree-use) are distinct from it and from the review-autofix marker — a scratch ledger carrying a seed-set entry, a green-tree entry and a green-tree-use entry selects neither marker via the seed rule (structural: neither marker string equals 'ARCHITECT mutual ACCEPT' or 'ARCHITECT rejected')" \
  "[ \"$SEED_RULE\" = 'ARCHITECT mutual ACCEPT' ] && [ \"$REVIEW_AUTOFIX_MARKER\" -ge 1 ] && [ 'green-tree' != 'ARCHITECT mutual ACCEPT' ] && [ 'green-tree-use' != 'ARCHITECT mutual ACCEPT' ]"

# =============================================================================
echo ""
echo "=== AC:untouched-fences (guard; branch-scoped per docs/doc-invariant-registry.md §2) — this cycle's diff stays inside the allow-list; HANDOFF/VALIDATE/rubric/tier-split sections show no hunks ==="
# =============================================================================
case "$HEAD_BRANCH" in
  dev/*-issue-88|dev/*-issue-88-*)
    BASE_REF="$(resolve_base_ref)"
    if [[ -z "$BASE_REF" ]]; then
      skip_no_base "AC:untouched-fences"
    else
      ALLOW_LIST=(
        "CLAUDE.md"
        "docs/autoflow-guide.md"
        "docs/teammate-contracts.md"
        "docs/submodule-common-rules.md"
        "setup/manifest.json"
        "tests/fixtures/doc-invariants.json"
        "tests/test-issue-88-tree-identity.sh"
        "tests/manual/issue-88-manual-scenarios.md"
        ".autoflow/issue-88-feature-design.md"
        ".autoflow/issue-88-verification-design.md"
        ".autoflow/issue-88-ledger.md"
      )
      DIFF_FILES="$(git -C "$PROJECT_ROOT" diff --name-only "$BASE_REF"...HEAD 2>/dev/null || true)"
      UNCOVERED="$(comm -23 <(printf '%s\n' "$DIFF_FILES" | sort) <(printf '%s\n' "${ALLOW_LIST[@]}" | sort))"
      UNCOVERED_OK=0; [ -z "$UNCOVERED" ] && UNCOVERED_OK=1
      assert_true "AC:untouched-fences (guard): diff file set ⊆ allow-list (uncovered: $(printf '%s' "$UNCOVERED" | paste -sd, -))" \
        "[ \"$UNCOVERED_OK\" = \"1\" ]"

      for SECTION_MARK in "## HANDOFF — PR Creation + Hand-off" "## VALIDATE — Verification Done" "## GATE:PLAN — Plan Evaluation" "## GATE:QUALITY — Completion Evaluation"; do
        HUNKS="$(git -C "$PROJECT_ROOT" diff "$BASE_REF"...HEAD -- docs/autoflow-guide.md 2>/dev/null \
          | awk -v m="$SECTION_MARK" 'index($0,"@@")==1{f=0} index($0,m)==1{f=1;next} f{print}' | grep -c '^[+-][^+-]' || true)"
        assert_true "AC:untouched-fences (guard): docs/autoflow-guide.md section '$SECTION_MARK' shows no diff hunks (got: $HUNKS changed lines)" \
          "[ \"$HUNKS\" = \"0\" ]"
      done
    fi
    ;;
  *)
    note_deferred "AC:untouched-fences: inert off the issue-88 dev branch"
    ;;
esac

# =============================================================================
echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
