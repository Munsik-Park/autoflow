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
# outcome), shared by the real-git oracles below so each carries only its own
# git sequence, not the mktemp/subshell/cleanup wrapper around it.
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
GREEN_BODY="$(extract_h2 "GREEN — Implementation" "$GUIDE")"

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
# Best-effort structural check: within the VERIFY body, the Mismatch branch
# marker must precede the first "no-entry" cause literal — the cause
# literals belong to the Mismatch branch, not the Match branch.
MISMATCH_LINE="$(printf '%s\n' "$VERIFY_BODY" | grep -nF -- '- **Mismatch**' | head -1 | cut -d: -f1)"
NOENTRY_LINE="$(printf '%s\n' "$VERIFY_BODY" | grep -nF 'no-entry' | head -1 | cut -d: -f1)"

assert_true "AC:mismatch-cause-record: the Mismatch branch marker precedes the first 'no-entry' cause literal (the record sits in the mismatch branch, not the match branch)" \
  "[ -n \"\${MISMATCH_LINE:-}\" ] && [ -n \"\${NOENTRY_LINE:-}\" ] && [ \"$MISMATCH_LINE\" -lt \"$NOENTRY_LINE\" ]"

# =============================================================================
echo ""
echo "=== AC:fallback-enumerated — neither VERIFY nor REFINE leaves a bare Match branch without its Mismatch fallback ==="
# =============================================================================
# Negative half of AC:fallback-enumerated (the positive half — no-entry /
# dirty-worktree / tree-differs each present — is carried by the registry
# entries 88-verify-mismatch-*). Every "**Match**" branch marker in a body
# must be paired with a "**Mismatch**" branch marker in the SAME body, so a
# future edit cannot silently drop the fallback while leaving the match arm.
VERIFY_MATCH_COUNT="$(printf '%s' "$VERIFY_BODY" | grep -cF -- '**Match**' || true)"
VERIFY_MISMATCH_COUNT="$(printf '%s' "$VERIFY_BODY" | grep -cF -- '**Mismatch**' || true)"
REFINE_MATCH_COUNT="$(printf '%s' "$REFINE_BODY" | grep -cF -- 'Match' || true)"
REFINE_MISMATCH_COUNT="$(printf '%s' "$REFINE_BODY" | grep -cF -- 'Mismatch' || true)"

# Presence-paired, not count-equal: VERIFY legitimately uses "**Match**"
# twice (once introducing the predicate's condition list, once as the
# branch bullet) against one "**Mismatch**" branch bullet — a real,
# non-defective asymmetry in the shipped prose structure that a strict
# count-equality check would misclassify as a bare match-branch.
VERIFY_PAIRED_OK=0; [ "$VERIFY_MATCH_COUNT" -ge 1 ] && [ "$VERIFY_MISMATCH_COUNT" -ge 1 ] && VERIFY_PAIRED_OK=1
REFINE_PAIRED_OK=0; [ "$REFINE_MATCH_COUNT" -ge 1 ] && [ "$REFINE_MISMATCH_COUNT" -ge 1 ] && REFINE_PAIRED_OK=1

assert_true "AC:fallback-enumerated (negative half): VERIFY carries both a Match and a Mismatch branch marker (Match: $VERIFY_MATCH_COUNT, Mismatch: $VERIFY_MISMATCH_COUNT) — no bare match-branch without its fallback" \
  "[ \"$VERIFY_PAIRED_OK\" = \"1\" ]"
assert_true "AC:fallback-enumerated (negative half): REFINE carries both a Match and a Mismatch branch marker (Match: $REFINE_MATCH_COUNT, Mismatch: $REFINE_MISMATCH_COUNT) — no bare match-branch without its fallback" \
  "[ \"$REFINE_PAIRED_OK\" = \"1\" ]"

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
for SRC in "CLAUDE.md" "docs/autoflow-guide.md" "docs/teammate-contracts.md" "docs/submodule-common-rules.md" "docs/doc-invariant-registry.md"; do
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
echo "=== Composition oracle — real scratch ledger: the two new markers are outside the ARCHITECT seed rule's authority match, and green-tree selection is unaffected by the other entry types (verification design row 3 / ledger E12) ==="
# =============================================================================
# Real interface for the seed rule: .claude/workflows/architect-deliberation.js's
# LEDGER_SEED_RULE instructs a whole-document read for entries "under
# authority \"ARCHITECT mutual ACCEPT\" or \"ARCHITECT rejected\"" — a
# field-value scan, not a marker-anchored heading match (unlike the
# Green-tree register's own marker-scoped selection). select_seed_set_count
# reproduces that same scan for real over an assembled ledger.
ARCHITECT_SEED_LITERAL_COUNT="$(grep -cF 'ARCHITECT mutual ACCEPT' "$ARCHITECT_WF" || true)"

select_seed_set_count() {  # <ledger_file> -> count of entries under the seed authority
  local ledger="$1"
  grep -cE '^- Authority: (ARCHITECT mutual ACCEPT|ARCHITECT rejected)' "$ledger" || true
}

make_ledger_composition() {  # <path> — a seed-set entry, verify-detection, review-autofix, green-tree, green-tree-use
  cat > "$1" <<'LEDGER'
# Decision Ledger — issue #88 (composition-oracle fixture)

## E1 — Some ARCHITECT decision (cycle 1, ARCHITECT)
- Decision: fixture decision line.
- Grounds: fixture grounds.
- Authority: ARCHITECT mutual ACCEPT. Cycle 1 / ARCHITECT.

## verify-detection | cycle 1 | VERIFY pass 1
- step-3 minimal-implementation: clean
- step-4 mock-boundary fidelity: clean
- iteration set: none
- grounds: fixture
- authority: VERIFY step 3/4 record

## review-autofix | cycle 1 | HANDOFF attempt 1
- finding: fixture Medium finding auto-resolved.
- authority: review-autofix record

### green-tree | cycle: 1 | runner: VERIFY step 1
- tree: ffff4444
- head: 99994444
- worktree: clean
- result: Tests: 8 passed, 8 total
- authority: Green-tree register

### green-tree-use | cycle: 1 | runner: REFINE step 2
- outcome: inherited
- mismatch-cause: none
- source: VERIFY step 1 cycle 1 | tree: ffff4444 | head: 99994444 | result: Tests: 8 passed, 8 total
- authority: Green-tree register
LEDGER
}

make_ledger_composition "$FIX_DIR/composition.md"

SEED_COUNT="$(select_seed_set_count "$FIX_DIR/composition.md")"
COMPOSITION_GREEN_TREE="$(select_green_tree_cycle "$FIX_DIR/composition.md" 1)"

SEED_COUNT_OK=0;  [ "$SEED_COUNT" = "1" ]                    && SEED_COUNT_OK=1
GREEN_TREE_OK=0;  [ "$COMPOSITION_GREEN_TREE" = "ffff4444" ]  && GREEN_TREE_OK=1

assert_true "composition-oracle: over a real assembled ledger carrying a seed-set entry, a verify-detection entry, a review-autofix entry and both new markers, the seed rule's authority scan selects exactly the one seed-set entry (count: $SEED_COUNT, expected 1 — green-tree/green-tree-use/verify-detection/review-autofix all carry a different authority value and are excluded)" \
  "[ \"$ARCHITECT_SEED_LITERAL_COUNT\" -ge 1 ] && [ \"$SEED_COUNT_OK\" = \"1\" ]"

assert_true "composition-oracle: over the SAME mixed ledger, select_green_tree_cycle still selects only the green-tree entry (got: '$COMPOSITION_GREEN_TREE', expected 'ffff4444') — the interspersed seed-set / verify-detection / review-autofix headings (all '## ', not the '### green-tree | cycle: ' marker) do not perturb the marker-scoped scan" \
  "[ \"$GREEN_TREE_OK\" = \"1\" ]"

# =============================================================================
echo ""
echo "=== Cycle 2 — GREEN step 5 producer site (PR #91 Medium finding) ==="
# =============================================================================
# Registry entries (origin_issue 88, ids 88-c2-*) pin the shipped literals at
# the GREEN section anchor. This block carries what the registry structurally
# cannot: cross-file/cross-block agreement, a clause-bound real-git negative
# oracle, and real-ledger cases over the (already runner-indifferent, cycle-1
# E23) selection mechanism applied to a GREEN-runner entry for the first time.

echo ""
echo "--- AC:evaluation-points-sync — the predicate's evaluation-point enumeration names GREEN step 5 alongside VERIFY step 1 / REFINE step 2, AND GREEN's own text self-names as GREEN step 5 ---"
ENUM_LINE="$(printf '%s\n' "$VERIFY_BODY" | grep -F 'Evaluated by the orchestrator at' | head -1)"
ENUM_HAS_GREEN=0;  printf '%s' "$ENUM_LINE" | grep -qF 'GREEN step 5'  && ENUM_HAS_GREEN=1
ENUM_HAS_VERIFY=0; printf '%s' "$ENUM_LINE" | grep -qF 'VERIFY step 1' && ENUM_HAS_VERIFY=1
ENUM_HAS_REFINE=0; printf '%s' "$ENUM_LINE" | grep -qF 'REFINE step 2' && ENUM_HAS_REFINE=1
GREEN_SELF_NAMES=0; printf '%s' "$GREEN_BODY" | grep -qF 'GREEN step 5' && GREEN_SELF_NAMES=1

assert_true "AC:evaluation-points-sync: the predicate's own evaluation-point sentence (VERIFY body, 'Evaluated by the orchestrator at ...') enumerates GREEN step 5 together with VERIFY step 1 and REFINE step 2, AND the GREEN section independently self-names 'GREEN step 5' — a cross-block agreement a single-file registry entry cannot express (enum-line: '$ENUM_LINE')" \
  "[ \"$ENUM_HAS_GREEN\" = 1 ] && [ \"$ENUM_HAS_VERIFY\" = 1 ] && [ \"$ENUM_HAS_REFINE\" = 1 ] && [ \"$GREEN_SELF_NAMES\" = 1 ]"

CLAUDE_PHASE_AGNOSTIC=0; grep -qF 'ran or inherited the suite' "$CLAUDE_MD" && CLAUDE_PHASE_AGNOSTIC=1
assert_true "AC:evaluation-points-sync (guard — CLAUDE.md's phase-exit coverage is already site-agnostic per ledger E32/GATE:PLAN carried risk (3): 'ran or inherited the suite' names no fixed phase pair, so GREEN exit is covered by extension without a text change; this locks that wording against a future accidental restriction to 'VERIFY/REFINE' only)" \
  "[ \"$CLAUDE_PHASE_AGNOSTIC\" = 1 ]"

echo ""
echo "--- AC:green-step-numbering-stable — the guide's cross-reference to GREEN's green-blocker step still resolves to the step that carries the green-blocker clause ---"
XREF_STEP="$(grep -oF -- 'GREEN step 2' "$GUIDE" | head -1 | grep -oE '[0-9]+')"
GREENBLOCKER_STEP="$(printf '%s\n' "$GREEN_BODY" | grep -B5 -F 'green-blocker.md' | grep -oE '^ *[0-9]+\.' | tail -1 | grep -oE '[0-9]+')"
assert_true "AC:green-step-numbering-stable (guard — appending step 5 must not renumber steps 1-4; the green-blocker clause stays at its own step and the cross-reference must keep resolving to it) (xref: '${XREF_STEP:-}', actual: '${GREENBLOCKER_STEP:-}')" \
  "[ -n \"\${XREF_STEP:-}\" ] && [ -n \"\${GREENBLOCKER_STEP:-}\" ] && [ \"$XREF_STEP\" = \"$GREENBLOCKER_STEP\" ]"

echo ""
echo "--- AC:registry-provenance-consistent — §9's entry-population citation and disposition rows stay true after this cycle's registry append ---"
REGISTRY_DOC="$PROJECT_ROOT/docs/doc-invariant-registry.md"
S9_QUERY_COUNT="$(jq '[.invariants[]|select(.origin_issue==88)]|length' "$PROJECT_ROOT/tests/fixtures/doc-invariants.json")"
S9_HAS_CITED_QUERY=0; grep -qF "jq '[.invariants[]|select(.origin_issue==88)]|length'" "$REGISTRY_DOC" && S9_HAS_CITED_QUERY=1
S9_HAS_TESTSH_ROW=0; grep -qF 'tests/test-issue-88-tree-identity.sh' "$REGISTRY_DOC" && S9_HAS_TESTSH_ROW=1
S9_HAS_MANUAL_ROW=0; grep -qF 'tests/manual/issue-88-manual-scenarios.md' "$REGISTRY_DOC" && S9_HAS_MANUAL_ROW=1
assert_true "AC:registry-provenance-consistent (guard — this cycle adds no new spec asset, only a registry append; §9 cites the population by a jq query rather than a frozen count and both cycle assets keep their disposition rows) (live population: $S9_QUERY_COUNT)" \
  "[ \"$S9_HAS_CITED_QUERY\" = 1 ] && [ \"$S9_HAS_TESTSH_ROW\" = 1 ] && [ \"$S9_HAS_MANUAL_ROW\" = 1 ]"

echo ""
echo "--- AC:green-exit-write negative half — real suppression oracle: both named states drive the write DECISION over a real ledger + the real selection command, clause-bound so a deleted shipped rule goes red ---"
GREEN_CLAUSE_CMD_STATUS="$(printf '%s' "$GREEN_BODY" | grep -oF 'git status --porcelain' | head -1)"
clause_names_green_capture_point() {
  case "$GREEN_CLAUSE_CMD_STATUS" in
    "git status --porcelain") : ;;
    *) return 1 ;;
  esac
  return 0
}

# clause_names_write_decision_rule — extracts the three literals the write
# DECISION below is a mechanical translation of: the capture-point command
# (already checked above), GREEN step 5's own three-condition gate ("when and
# only when all three hold", docs/autoflow-guide.md:485), and the register's
# suppression sentence ("no entry is written for it", the Green-tree register
# Capture point paragraph under VERIFY). If any is deleted from the shipped
# text, this fails closed — which is what makes green_step5_write_decision's
# fixed behavior (unaffected by doc edits, since it is bash, not a doc reader)
# a discriminator rather than a standing proxy: the AND-combination with this
# clause check is what goes red on a deleted rule.
clause_names_write_decision_rule() {
  clause_names_green_capture_point || return 1
  printf '%s' "$GREEN_BODY" | grep -qF 'when and only when all three hold' || return 1
  printf '%s' "$VERIFY_BODY" | grep -qF 'no entry is written for it' || return 1
  return 0
}

# green_step5_write_decision <worktree_status> <all_pass:0|1> -> "write" | "no-write"
# A direct mechanical translation of GREEN step 5's own write rule (condition
# 1: capture point clean; condition 2: run all-PASS). Condition 3 (registrable
# scope) has no repository-side oracle (§6 / ledger E24 — a writer-side
# [MUST] over an execution fact) and is out of what this decision function
# drives; it is treated as satisfied here, same as every other real-git case
# in this suite.
green_step5_write_decision() {
  local worktree_status="$1" all_pass="$2"
  if [ -n "$worktree_status" ]; then
    printf 'no-write'; return
  fi
  if [ "$all_pass" != "1" ]; then
    printf 'no-write'; return
  fi
  printf 'write'
}

# is_pass_result_line <result_line> -> 0 (pass) / 1 (non-pass). Models the
# predicate's condition 3 ("that entry's `result` is a pass line") against
# the shipped result convention — per-suite "N/M passed" segments (the
# ledger's own recorded entries, e.g. "tests/test-issue-88-tree-identity.sh
# 42/42 passed; tests/run-doc-invariants.sh 528/528 passed"). Primary signal:
# every "N/M passed" segment must have N == M. Secondary signal: an explicit
# nonzero "<N> [word] failed" count (covers summary-line shapes with no N/M
# fraction, e.g. "Results: 3 tests failed").
is_pass_result_line() {
  local line="$1" failed_count seg n m
  failed_count="$(printf '%s' "$line" | grep -oE '[0-9]+ ([a-zA-Z]+ )?failed' | grep -oE '^[0-9]+' | sort -n | tail -1)"
  if [ -n "$failed_count" ] && [ "$failed_count" -gt 0 ] 2>/dev/null; then
    return 1
  fi
  while read -r seg; do
    [ -z "$seg" ] && continue
    n="${seg%%/*}"
    m="${seg#*/}"
    m="${m%% passed}"
    [ "$n" != "$m" ] && return 1
  done < <(printf '%s' "$line" | grep -oE '[0-9]+/[0-9]+ passed')
  return 0
}

# select_green_tree_cycle_pass_only <ledger_file> <cycle> — select_green_tree_cycle
# plus condition 3 (is_pass_result_line above), which plain selection does not
# check (it only implements condition 2's marker-scoped-then-positional rule).
select_green_tree_cycle_pass_only() {
  local ledger="$1" cycle="$2" tree result
  tree="$(select_green_tree_cycle "$ledger" "$cycle")"
  [ -z "$tree" ] && return 0
  result="$(awk -v cyc="$cycle" '
    /^### green-tree \| cycle: / {
      line=$0; sub(/^### green-tree \| cycle: /,"",line); split(line, parts, " | ")
      in_sel = (parts[1] == cyc); next
    }
    /^### / { in_sel=0; next }
    in_sel && /^- result: / { r=$0; sub(/^- result: /,"",r); last_result=r }
    END { print last_result }
  ' "$ledger")"
  is_pass_result_line "$result" || return 0
  printf '%s' "$tree"
}

# State (a) — the write DECISION, not a pre-emptied ledger: the ledger is
# populated by APPLYING green_step5_write_decision's verdict (write iff
# "write"), for both a dirty capture point (untracked non-ignored path — the
# design's named realization) and a clean one, so the same body carries a
# negative case and the positive control that proves apply-to-ledger is not
# trivially a no-op.
green_write_decision_ledger_body() {
  # The git repo lives in its own subdirectory so the ledger fixture file
  # (written into the scratch dir below) never becomes an untracked path
  # inside the repo itself — that would self-pollute the "clean" branch's
  # status check with an artifact of the test apparatus, not the state under
  # test.
  mkdir repo
  git -C repo init -q
  git -C repo config user.email t@example.com
  git -C repo config user.name tester
  echo one > repo/f.txt
  git -C repo add f.txt
  git -C repo commit -q -m init

  echo stray > repo/untracked.txt   # untracked, non-ignored: makes the capture point dirty
  S_DIRTY="$(git -C repo status --porcelain)"
  [ -n "$S_DIRTY" ]
  DECISION_DIRTY="$(green_step5_write_decision "$S_DIRTY" 1)"
  [ "$DECISION_DIRTY" = "no-write" ]
  : > ledger.md
  [ "$DECISION_DIRTY" = "write" ] && printf 'unreachable\n' >> ledger.md
  SEL_DIRTY="$(select_green_tree_cycle ledger.md 1)"
  [ -z "$SEL_DIRTY" ]   # no entry became offerable

  rm repo/untracked.txt
  S_CLEAN="$(git -C repo status --porcelain)"
  [ -z "$S_CLEAN" ]
  DECISION_CLEAN="$(green_step5_write_decision "$S_CLEAN" 1)"
  [ "$DECISION_CLEAN" = "write" ]
  T="$(git -C repo rev-parse HEAD^{tree})"
  : > ledger.md
  if [ "$DECISION_CLEAN" = "write" ]; then
    cat >> ledger.md <<LEDGER
### green-tree | cycle: 1 | runner: GREEN step 5
- tree: $T
- head: $(git -C repo rev-parse HEAD)
- worktree: clean
- result: 3/3 passed, 0 failed
- authority: Green-tree register
LEDGER
  fi
  SEL_CLEAN="$(select_green_tree_cycle ledger.md 1)"
  [ "$SEL_CLEAN" = "$T" ]   # the entry the decision wrote IS offerable
}
green_write_decision_ledger() { run_in_scratch_dir "green-write-decision" green_write_decision_ledger_body; }

# State (b) — a current-cycle entry whose `result` is a non-pass line. Plain
# marker/cycle/positional selection DOES find it (proving the fixture itself
# is well-formed under the entry grammar); the predicate's condition 3 must
# still refuse it. Includes a pass-line control so the wrapper is shown not to
# over-reject.
green_nonpass_result_rejected_body() {
  cat > ledger.md <<'LEDGER'
### green-tree | cycle: 1 | runner: GREEN step 5
- tree: deadbeef1234
- head: cafef00d5678
- worktree: clean
- result: Results: 39/42 passed, 3 failed
- authority: Green-tree register
LEDGER
  SEL_PLAIN="$(select_green_tree_cycle ledger.md 1)"
  [ "$SEL_PLAIN" = "deadbeef1234" ]
  SEL_PASS_ONLY="$(select_green_tree_cycle_pass_only ledger.md 1)"
  [ -z "$SEL_PASS_ONLY" ]
  # control: an otherwise-identical entry with a pass-line result is not rejected
  cat > ledger-pass.md <<'LEDGER'
### green-tree | cycle: 1 | runner: GREEN step 5
- tree: deadbeef1234
- head: cafef00d5678
- worktree: clean
- result: Results: 42/42 passed, 0 failed
- authority: Green-tree register
LEDGER
  SEL_PASS_CONTROL="$(select_green_tree_cycle_pass_only ledger-pass.md 1)"
  [ "$SEL_PASS_CONTROL" = "deadbeef1234" ]
}
green_nonpass_result_rejected() { run_in_scratch_dir "green-nonpass-result" green_nonpass_result_rejected_body; }

assert_true "AC:green-exit-write (negative half), state (a): the write DECISION (mechanical translation of GREEN step 5's own three-condition gate, clause-bound — fails if the gate/suppression sentence is deleted from the shipped text) is applied to a real ledger for a dirty capture point (untracked non-ignored path) and a clean one; the real select_green_tree_cycle command finds nothing offerable on the dirty run and finds exactly the written entry on the clean run" \
  "clause_names_write_decision_rule && green_write_decision_ledger"

assert_true "AC:green-exit-write (negative half), state (b) non-pass \`result\`: a real ledger's current-cycle entry with a failing result line IS found by plain marker/cycle/positional selection but IS refused by the predicate's condition 3 (result must be a pass line, modelled on the shipped per-suite 'N/M passed' convention) — first executable coverage of condition 3, which every other fixture's pass-line result left untested; a pass-line control confirms the wrapper does not over-reject" \
  "green_nonpass_result_rejected"

echo ""
echo "--- AC:first-verify-inherits-holds — a real ledger's current-cycle GREEN-runner entry is selectable and tree-bound (real git, mktemp -d scratch repo) ---"
green_runner_ledger_oracle_body() {
  git init -q
  git config user.email t@example.com
  git config user.name tester
  echo seed > f.txt
  git add f.txt
  git commit -q -m seed
  T0="$(git rev-parse HEAD^{tree})"
  cat > ledger.md <<LEDGER
# Decision Ledger — issue #88 (fixture)

### green-tree | cycle: 1 | runner: GREEN step 5
- tree: $T0
- head: $(git rev-parse HEAD)
- worktree: clean
- result: Tests: 5 passed, 5 total
- authority: Green-tree register
LEDGER
  SEL0="$(select_green_tree_cycle ledger.md 1)"
  [ "$SEL0" = "$T0" ]
  # a tracked change after the capture point moves the tree -> the same entry no longer matches HEAD^{tree}
  echo two >> f.txt
  git add f.txt
  git commit -q -m change
  T1="$(git rev-parse HEAD^{tree})"
  [ "$T1" != "$T0" ]
  SEL1="$(select_green_tree_cycle ledger.md 1)"
  # selection still returns the recorded (now-stale) tree; it is the caller's job
  # (predicate condition 2) to compare it against the *current* HEAD^{tree}
  [ "$SEL1" = "$T0" ]
  [ "$SEL1" != "$T1" ]
}
green_runner_ledger_oracle() { run_in_scratch_dir "green-runner-ledger" green_runner_ledger_oracle_body; }

assert_true "AC:first-verify-inherits-holds (guard — selection is already runner-indifferent per cycle-1 E23; this locks that property specifically for a GREEN-runner entry, the new producer this cycle introduces, so a future regression that special-cases 'runner' cannot silently exclude it): a real assembled ledger's current-cycle 'runner: GREEN step 5' entry is selected by tree on an unmoved tree, and a subsequent commit moves HEAD^{tree} away from the recorded value" \
  "green_runner_ledger_oracle"

echo ""
echo "--- AC:runner-vocabulary (ordering variant) — a later GREEN-runner entry outranks an earlier VERIFY-runner entry of the same cycle by position, not by phase name (real ledger) ---"
mixed_runner_ledger_oracle_body() {
  cat > ledger.md <<'LEDGER'
# Decision Ledger — issue #88 (fixture)

### green-tree | cycle: 1 | runner: VERIFY step 1
- tree: verifytree1111
- head: verifyhead1111
- worktree: clean
- result: Tests: 9 passed, 9 total
- authority: Green-tree register

### green-tree | cycle: 1 | runner: GREEN step 5
- tree: greentree2222
- head: greenhead2222
- worktree: clean
- result: Tests: 9 passed, 9 total
- authority: Green-tree register
LEDGER
  SEL="$(select_green_tree_cycle ledger.md 1)"
  [ "$SEL" = "greentree2222" ]
}
mixed_runner_ledger_oracle() { run_in_scratch_dir "mixed-runner-ledger" mixed_runner_ledger_oracle_body; }

assert_true "AC:runner-vocabulary ordering (guard — same runner-indifference property, exercised in the direction the vocabulary sentence protects: an admissible-phase list must not read as a precedence order): a later cycle-1 GREEN-runner entry is selected over an earlier cycle-1 VERIFY-runner entry, by position alone" \
  "mixed_runner_ledger_oracle"

echo ""
echo "--- AC:green-reentry-disposition — a VERIFY→GREEN re-entry landing no tracked change matches the prior VERIFY-exit entry; landing a tracked change mismatches (real git + real ledger) ---"
green_reentry_oracle_body() {
  git init -q
  git config user.email t@example.com
  git config user.name tester
  echo seed > f.txt
  git add f.txt
  git commit -q -m seed
  T0="$(git rev-parse HEAD^{tree})"
  cat > ledger.md <<LEDGER
# Decision Ledger — issue #88 (fixture)

### green-tree | cycle: 1 | runner: VERIFY step 1
- tree: $T0
- head: $(git rev-parse HEAD)
- worktree: clean
- result: Tests: 5 passed, 5 total
- authority: Green-tree register
LEDGER
  SEL_MATCH="$(select_green_tree_cycle ledger.md 1)"
  S_CLEAN="$(git status --porcelain)"
  CUR_TREE="$T0"
  # re-entry landing no tracked change: worktree clean, HEAD^{tree} unchanged -> match
  [ -z "$S_CLEAN" ]
  [ "$SEL_MATCH" = "$CUR_TREE" ]
  # re-entry landing a tracked change: HEAD^{tree} moves away from the recorded entry -> mismatch (tree-differs)
  echo two >> f.txt
  git add f.txt
  git commit -q -m fix
  CUR_TREE2="$(git rev-parse HEAD^{tree})"
  [ "$CUR_TREE2" != "$SEL_MATCH" ]
}
green_reentry_oracle() { run_in_scratch_dir "green-reentry" green_reentry_oracle_body; }

assert_true "AC:green-reentry-disposition (guard — same selection/comparison mechanism, driven over the specific re-entry shape §2.5 describes: a prior VERIFY-exit entry either matches an unmoved GREEN re-entry tree or mismatches a moved one)" \
  "green_reentry_oracle"

echo ""
echo "--- AC:green-exit-failure-disposition (agreement half) — VERIFY step 2's cause-branch routing text is unchanged by this cycle's diff, so a failed GREEN acceptance run is adjudicated by the pre-existing branching, not a new gate (branch-scoped) ---"
case "$HEAD_BRANCH" in
  dev/*-issue-88|dev/*-issue-88-*)
    C2_BASE_REF="$(resolve_base_ref)"
    if [[ -z "$C2_BASE_REF" ]]; then
      skip_no_base "AC:green-exit-failure-disposition (agreement half)"
    else
      ROUTING_DIFF="$(git -C "$PROJECT_ROOT" diff "$C2_BASE_REF"...HEAD -- docs/autoflow-guide.md 2>/dev/null)"
      ROUTING_TOUCHED=0
      for MARKER in 'fix_test + no_problem' 'no_problem + fix_impl' 'fix_test + fix_impl' 'no_problem + no_problem'; do
        printf '%s\n' "$ROUTING_DIFF" | grep -E '^[+-]' | grep -qF -- "$MARKER" && ROUTING_TOUCHED=1
      done
      ROUTING_UNTOUCHED_OK=0; [ "$ROUTING_TOUCHED" = 0 ] && ROUTING_UNTOUCHED_OK=1
      assert_true "AC:green-exit-failure-disposition (agreement half): none of the four VERIFY step 2 cause-branch routing lines (fix_test+no_problem/no_problem+fix_impl/fix_test+fix_impl/no_problem+no_problem) appear as an added or removed diff line — the design's 'no flow-control transition changes' claim reduced to a checkable fact" \
        "[ \"$ROUTING_UNTOUCHED_OK\" = \"1\" ]"
    fi
    ;;
  *)
    note_deferred "AC:green-exit-failure-disposition (agreement half): inert off the issue-88 dev branch"
    ;;
esac

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
        "docs/doc-invariant-registry.md"
        "setup/manifest.json"
        "tests/fixtures/doc-invariants.json"
        "tests/test-issue-88-tree-identity.sh"
        "tests/manual/issue-88-manual-scenarios.md"
        ".github/workflows/contract-suites.yml"
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
