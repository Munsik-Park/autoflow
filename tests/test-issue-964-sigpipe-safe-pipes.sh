#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: SIGPIPE-safe assertion pipes guard — Issue #964
# =============================================================================
# Tier-1 scripted assertion suite per verification design
# (.autoflow/issue-964-verification-design.md). Docs/ops meta-suite (no jest,
# no npm) — mirrors tests/test-issue-949-manifest-regen-doc.sh /
# tests/test-issue-955-subagent-background-ban.sh: assert_true/assert_false
# over grep/awk section extraction + eval-bound fixture equivalence.
#
# Central testability note (verification design §0): the race itself
# (producer/consumer SIGPIPE timing under `pipefail`) is NOT deterministically
# reproducible at the pipelines' real (small) data volume — 500/500 local
# iterations rc=0 (hypotheses.md). This suite therefore gates the three
# DETERMINISTIC surfaces the design pivots onto instead of the race: (1) the
# structural anti-pattern's absence (AC1-A/AC2-A), (2) semantic-equivalence
# discrimination preserved (AC1-C), (3) the safe-pattern convention is
# documented (AC3-A). AC4 is a Green-follow regression guard, not an
# independent RED discriminator (§1 AC4-A).
#
# Scope (verification design §1/§3):
#   AC2-A   — RED discriminator (primary): repo-wide zero-remaining guard —
#             no `tests/*.sh` line matches the canonical hazard shape
#             `grep -[ABC] ?[0-9]+ [^)]*\| grep -q` (verification design §1a).
#             Fails now (13 lines across 5 files); passes only once every FIX
#             line lands in one of the three safe shapes (feature design §4
#             Safe-form lock).
#   AC2-B   — inventory cross-check (guard, informational pre-fix): the
#             hazard-line file set and count match the Phase-3 baseline (5
#             files; 13 assertion lines / 18 pipe-instances — count-basis
#             correction per GATE:PLAN ledger E10, gate count unchanged at
#             13 LINES). Vacuous PASS once the guard is already clear.
#   AC1-A   — RED discriminator: local guard scoped to
#             test-issue-949-manifest-regen-doc.sh (the observed AC-CI-b at
#             :306 + its sibling :308). Subsumed by AC2-A; kept as the
#             issue-named discriminator.
#   AC1-C   — RED discriminator (negative-equivalence, source-extraction
#             binding): the shipped AC-CI-b condition string is extracted
#             verbatim from the committed 949 script at test time (never
#             hand-copied — cannot drift from the actual edit), then eval'd
#             with CI_WORKFLOW bound to two fixtures: (i) reference under a
#             `paths:` block → expect PASS: (ii) reference only under a
#             `run:` step, no `paths:` line within the window → expect FAIL.
#             Proves the shipped condition still discriminates the windowed
#             positional coupling after the fix lands.
#   AC3-A   — RED discriminator: docs/submodule-common-rules.md > Testing
#             Standards names `pipefail`, `SIGPIPE`, and the capture-then-grep
#             guidance. Fails now (zero matches, verified baseline).
#   AC4-A   — Green-follow guard (NOT a RED discriminator): the sibling
#             suites edited by the AC2 sweep (798/799/955; 800/949 retired
#             by #951) — the regression oracle for those edits (verification
#             design §5) — stay green.
#   AC4-B   — informational: records which grep (wrapper vs real) this run
#             used, since the dev-shell wrapper cannot reproduce the race
#             (verification design AC4-B) — a wrapper-only green is
#             regression evidence, NOT fix-effect evidence.
#
# Not in this file (verification design §1 AC1-D / §4 item 3): forced-race
# reproduction is an environment-dependent demonstration (real grep + an
# artificially inflated producer), not a CI gate — committing it risks a NEW
# flaky test, the opposite of this issue's intent.
#
# RED expectation (pre-edit, this commit, per verification design §3):
# AC2-A, AC1-A, AC3-A FAIL. AC1-C's own two assertions PASS pre-edit (the
# *current* :306 line already discriminates the fixtures correctly) but the
# suite is RED overall via AC2-A/AC1-A until the fix lands (verification
# design §3 item 3). AC2-B is vacuously informational while AC2-A is
# non-empty. AC4-A/AC4-B are guards, expected green pre-edit (nothing broken
# yet).
#
# Self-guard (dogfood): this suite's own assertions use plain `grep -nE`/
# `awk`/`grep -rnE` (no `-A/-B/-C` context flag piped into `grep -q`) — it
# does not introduce a new instance of the defect class it tests for. The
# only occurrence of the literal hazard SHAPE in this file is inside
# mktemp-generated fixture content (never a committed tests/*.sh line) and
# the AC1-C source-extraction result (a runtime variable, never a literal
# line in this .sh source) — matching verification design §1a's "Self-match
# footgun" guidance.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SUBMODULE_COMMON="$PROJECT_ROOT/docs/submodule-common-rules.md"
FILE_949="$PROJECT_ROOT/tests/test-issue-949-manifest-regen-doc.sh"

# Canonical guard regex — single source, verification design §1a / feature
# design §8.1, cited verbatim. Matches the compound "context-mode producer
# piped directly into a short-circuit consumer" shape; the `[^)]*` (no
# closing paren before the pipe) is exactly what lets the guard CLEAR the
# mandated capture-then-printf fix (the `$(...)` closing `)` breaks it).
GUARD_REGEX='grep -[ABC] ?[0-9]+ [^)]*\| grep -q'

# Second named guard — issue #973, extractor-function producer class
# (feature §4.1 / verification §2 DCR-1, ledger E4, frozen regex). Matches a
# bare-identifier extractor function (e.g. `claude_issue_mgmt_section`) piped
# directly into a short-circuiting consumer (`grep -q`/`grep -m`). Kept as a
# SEPARATE named regex/baseline from GUARD_REGEX (never folded in) so AC2-B's
# compound inventory (5 files/13 lines) stays untouched (ledger E8).
EXTRACTOR_GUARD_REGEX='(^|[[:space:]"'"'"'])[a-zA-Z_][a-zA-Z0-9_]* \| grep -[qm]'

PASS=0; FAIL=0; TESTS=0

# ---------------------------------------------------------------------------
# Helpers (assert_* pattern per tests/test-issue-949-manifest-regen-doc.sh)
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

extract_section() {
  local heading_pattern="$1" file="$2"
  awk -v p="$heading_pattern" '
    $0 ~ p { f=1; next }
    f && /^## / { f=0 }
    f && /^---$/ { f=0 }
    f { print }
  ' "$file"
}

# =============================================================================
echo "=== AC2-A (RED discriminator, primary) — repo-wide zero-remaining guard ==="
# Single grep -rnE scan (no piped short-circuit consumer) — self-safe.

REPO_MATCHES="$(grep -rnE "$GUARD_REGEX" "$PROJECT_ROOT"/tests/*.sh 2>/dev/null || true)"
if [[ -n "$REPO_MATCHES" ]]; then
  REPO_MATCH_COUNT="$(printf '%s\n' "$REPO_MATCHES" | grep -c .)"
else
  REPO_MATCH_COUNT=0
fi
echo "  hazard lines found: $REPO_MATCH_COUNT"
[[ "$REPO_MATCH_COUNT" -gt 0 ]] && printf '%s\n' "$REPO_MATCHES" | sed 's/^/    /'

assert_true "AC2-A: zero tests/*.sh lines match the compound hazard shape (grep -[ABC] context producer piped directly into grep -q)" \
  "[ $REPO_MATCH_COUNT -eq 0 ]"

# =============================================================================
echo ""
echo "=== AC2-B (inventory cross-check, guard) — hazard set matches the Phase-3 baseline ==="

if [[ "$REPO_MATCH_COUNT" -gt 0 ]]; then
  HAZARD_FILE_LIST="$(printf '%s\n' "$REPO_MATCHES" | cut -d: -f1 | xargs -n1 basename | sort -u | tr '\n' ' ' | sed 's/ *$//')"
  # #951 retired-guard disposition: test-issue-800-doc-assertions.sh and
  # test-issue-949-manifest-regen-doc.sh are DELETED by #951 (migrated into
  # tests/fixtures/doc-invariants.json / tests/run-doc-invariants.sh,
  # docs/doc-invariant-registry.md disposition table) — the sigpipe hazard-
  # oracle set can no longer include files that no longer exist.
  EXPECTED_FILE_LIST="test-issue-798-topology-flip.sh test-issue-799-inert-cleanup.sh test-issue-955-subagent-background-ban.sh"
  echo "  hazard files: $HAZARD_FILE_LIST"
  assert_true "AC2-B: hazard-line file set matches the Phase-3 baseline (798/799/955; 800/949 retired by #951)" \
    "[ \"$HAZARD_FILE_LIST\" = \"$EXPECTED_FILE_LIST\" ]"
  assert_true "AC2-B: hazard-line count matches the Phase-3 baseline (13 assertion lines / 18 pipe-instances — count basis: lines, ledger E10)" \
    "[ $REPO_MATCH_COUNT -eq 13 ]"
else
  echo "  PASS (vacuous): AC2-B baseline cross-check — guard already clear (post-fix state), baseline no longer applicable"
  TESTS=$((TESTS + 2)); PASS=$((PASS + 2))
fi

# =============================================================================
echo ""
echo "=== AC2-A2 (RED discriminator, issue #973) — repo-wide zero-remaining extractor-producer guard ==="
# Second named regex, self-inclusive scan (globs tests/*.sh INCLUDING this
# file itself — self-trip guard re-confirms 964's own new lines contribute 0,
# ledger E9). Single grep -rnE scan (no piped short-circuit consumer) — self-safe.

EXTRACTOR_MATCHES="$(grep -rnE "$EXTRACTOR_GUARD_REGEX" "$PROJECT_ROOT"/tests/*.sh 2>/dev/null || true)"
if [[ -n "$EXTRACTOR_MATCHES" ]]; then
  EXTRACTOR_MATCH_COUNT="$(printf '%s\n' "$EXTRACTOR_MATCHES" | grep -c .)"
else
  EXTRACTOR_MATCH_COUNT=0
fi
echo "  extractor-producer hazard lines found: $EXTRACTOR_MATCH_COUNT"
[[ "$EXTRACTOR_MATCH_COUNT" -gt 0 ]] && printf '%s\n' "$EXTRACTOR_MATCHES" | sed 's/^/    /'

assert_true "AC2-A2: zero tests/*.sh lines match the extractor-function producer hazard shape (bare-identifier fn piped into grep -q/-m), including this suite itself" \
  "[ $EXTRACTOR_MATCH_COUNT -eq 0 ]"

# =============================================================================
echo ""
echo "=== AC2-B2 (inventory cross-check, guard, issue #973) — extractor-producer hazard set matches scope-A baseline ==="
# Separate inventory from AC2-B's compound baseline (5 files/13 lines,
# unaffected by this issue — ledger E8). Scope-A baseline was originally
# 4 files / 10 lines (test-issue-799(1)/800(7)/846(1)/848(1) — ledger E6).
# #951 retired-guard disposition (same disposition as AC2-B above):
# test-issue-800-doc-assertions.sh is DELETED by #951 (migrated into
# tests/fixtures/doc-invariants.json / tests/run-doc-invariants.sh,
# docs/doc-invariant-registry.md disposition table) — the extractor-producer
# hazard-oracle set can no longer include a file that no longer exists.

if [[ "$EXTRACTOR_MATCH_COUNT" -gt 0 ]]; then
  EXTRACTOR_FILE_LIST="$(printf '%s\n' "$EXTRACTOR_MATCHES" | cut -d: -f1 | xargs -n1 basename | sort -u | tr '\n' ' ' | sed 's/ *$//')"
  EXTRACTOR_EXPECTED_FILE_LIST="test-issue-799-inert-cleanup.sh test-issue-846-doc-assertions.sh test-issue-848-doc-assertions.sh"
  echo "  hazard files: $EXTRACTOR_FILE_LIST"
  assert_true "AC2-B2: extractor-producer hazard-line file set matches the scope-A baseline (799/846/848; 800 retired by #951)" \
    "[ \"$EXTRACTOR_FILE_LIST\" = \"$EXTRACTOR_EXPECTED_FILE_LIST\" ]"
  assert_true "AC2-B2: extractor-producer hazard-line count matches the scope-A baseline (3 files / 3 lines; 800's 7 lines retired by #951)" \
    "[ $EXTRACTOR_MATCH_COUNT -eq 3 ]"
else
  echo "  PASS (vacuous): AC2-B2 baseline cross-check — extractor-producer guard already clear (post-fix state), baseline no longer applicable"
  TESTS=$((TESTS + 2)); PASS=$((PASS + 2))
fi

# =============================================================================
echo ""
echo "=== AC1-A (RED discriminator) — local guard: test-issue-949-manifest-regen-doc.sh (:306/:308) ==="
# Subsumed by AC2-A; kept as the issue-named discriminator (verification
# design §3 item 2).

MATCH_949="$(grep -nE "$GUARD_REGEX" "$FILE_949" 2>/dev/null || true)"
if [[ -n "$MATCH_949" ]]; then
  MATCH_949_COUNT="$(printf '%s\n' "$MATCH_949" | grep -c .)"
else
  MATCH_949_COUNT=0
fi
echo "  matches: ${MATCH_949:-<none>}"
assert_true "AC1-A: test-issue-949-manifest-regen-doc.sh carries no hazardous compound-pipe shape (AC-CI-b :306 + sibling :308)" \
  "[ $MATCH_949_COUNT -eq 0 ]"

# =============================================================================
echo ""
echo "=== AC1-C (RED discriminator, negative-equivalence) — source-extraction binding ==="
# CI_WORKFLOW is hardcoded at 949:94 (not env-overridable), so the whole 949
# script cannot be re-pointed at a fixture. Instead: extract the shipped
# AC-CI-b condition string verbatim from the committed script, then eval it
# with CI_WORKFLOW textually substituted for two fixture paths. This binds
# AC1-C to whatever the Developer AI actually ships — it cannot drift from a
# hand-typed duplicate.

if [[ -f "$FILE_949" ]]; then
  AC_CI_B_RAW="$(awk '/AC-CI-b: reference appears in a/{getline; print; exit}' "$FILE_949")"
  AC_CI_B_EXPR="$(printf '%s' "$AC_CI_B_RAW" | sed -E 's/^[[:space:]]*"//; s/"[[:space:]]*$//')"
  if [[ -n "$AC_CI_B_EXPR" ]]; then EXTRACT_OK=0; else EXTRACT_OK=1; fi
  assert_true "AC1-C: source-extraction of the shipped AC-CI-b condition string (949, following the AC-CI-b description line) succeeded" \
    "[ $EXTRACT_OK -eq 0 ]"
else
  # #951 retired-guard disposition: test-issue-949-manifest-regen-doc.sh is
  # DELETED by #951 (docs/doc-invariant-registry.md dropped/redundant
  # disposition — its CI-registration intent is subsumed by #951's own
  # AC5 case-4a: 794/796/797 reachable through the single runner step).
  # AC1-C's negative-equivalence source no longer exists to extract from —
  # vacuous-informational, matching this file's own AC2-B vacuous-pass
  # convention above, not a hard extraction FAIL.
  echo "  PASS (vacuous): AC1-C — test-issue-949-manifest-regen-doc.sh retired by #951 (dropped/redundant disposition); no extraction source remains"
  TESTS=$((TESTS + 1)); PASS=$((PASS + 1))
  EXTRACT_OK=1
  FILE_949_RETIRED=1
fi

if [[ "$EXTRACT_OK" -eq 0 ]]; then
  FIX_DIR="$(mktemp -d)"
  trap 'rm -rf "$FIX_DIR"' EXIT

  {
    echo "name: fixture-i"
    echo "on:"
    echo "  pull_request:"
    echo "    paths:"
    echo "      - 'tests/test-issue-949-manifest-regen-doc.sh'"
    echo "      - 'other/path.sh'"
    echo "jobs:"
    echo "  x:"
    echo "    steps:"
    echo "      - run: bash tests/test-issue-949-manifest-regen-doc.sh"
  } > "$FIX_DIR/fixture-i.yml"

  {
    echo "name: fixture-ii"
    echo "on:"
    echo "  pull_request:"
    echo "    paths:"
    echo "      - 'unrelated/file-a.sh'"
    echo "      - 'unrelated/file-b.sh'"
    for i in $(seq 1 33); do echo "    # padding line $i (keeps the unrelated paths: block >30 lines from the run: reference below)"; done
    echo "jobs:"
    echo "  x:"
    echo "    steps:"
    echo "      - run: bash tests/test-issue-949-manifest-regen-doc.sh"
  } > "$FIX_DIR/fixture-ii.yml"

  # Textual substitution (not shell-variable expansion): the extracted
  # expression carries the literal, unexpanded token $CI_WORKFLOW inside
  # single quotes; substituting the token's text — rather than relying on a
  # CI_WORKFLOW shell variable — sidesteps the single-quote-vs-double-quote
  # boundary shift between the extraction site (949's double-quoted source)
  # and this eval site (a bare re-parsed command line).
  EXPR_FIXTURE_I="$(printf '%s' "$AC_CI_B_EXPR" | sed "s#\$CI_WORKFLOW#$FIX_DIR/fixture-i.yml#g")"
  EXPR_FIXTURE_II="$(printf '%s' "$AC_CI_B_EXPR" | sed "s#\$CI_WORKFLOW#$FIX_DIR/fixture-ii.yml#g")"

  if (cd "$PROJECT_ROOT" && eval "$EXPR_FIXTURE_I"); then FIXTURE_I_RESULT=0; else FIXTURE_I_RESULT=1; fi
  if (cd "$PROJECT_ROOT" && eval "$EXPR_FIXTURE_II"); then FIXTURE_II_RESULT=0; else FIXTURE_II_RESULT=1; fi

  assert_true "AC1-C: extracted AC-CI-b expression PASSES fixture (i) — reference present under a paths: block" \
    "[ $FIXTURE_I_RESULT -eq 0 ]"
  assert_true "AC1-C: extracted AC-CI-b expression FAILS fixture (ii) — reference only under a run: step, no paths: line within the window" \
    "[ $FIXTURE_II_RESULT -eq 1 ]"

  rm -rf "$FIX_DIR"
  trap - EXIT
elif [[ "${FILE_949_RETIRED:-0}" -eq 1 ]]; then
  echo "  PASS (vacuous): AC1-C fixture assertions — no extraction source (949 retired by #951)"
  TESTS=$((TESTS + 2)); PASS=$((PASS + 2))
else
  echo "  SKIP: fixture assertions (extraction failed — see the extraction-succeeded assertion above)"
  TESTS=$((TESTS + 2))
fi

# =============================================================================
echo ""
echo "=== AC3-A (RED discriminator, doc-assertion) — Testing Standards safe-pattern convention ==="

TESTING_STANDARDS_BODY="$(extract_section '^## Testing Standards' "$SUBMODULE_COMMON")"
TESTING_STANDARDS_JOINED="$(printf '%s' "$TESTING_STANDARDS_BODY" | tr '\n' ' ')"
export TESTING_STANDARDS_JOINED

assert_true "AC3-A: Testing Standards section names 'pipefail'" \
  "printf '%s' \"\$TESTING_STANDARDS_JOINED\" | grep -qF 'pipefail'"
assert_true "AC3-A: Testing Standards section names 'SIGPIPE'" \
  "printf '%s' \"\$TESTING_STANDARDS_JOINED\" | grep -qF 'SIGPIPE'"
assert_true "AC3-A: Testing Standards section documents the capture-then-grep guidance (a capture assignment token or a \$(...) command-substitution form)" \
  "printf '%s' \"\$TESTING_STANDARDS_JOINED\" | grep -qE 'capture|\\\$\\('"
assert_true "AC3 (issue #973): Testing Standards section names the extractor-function producer case" \
  "printf '%s' \"\$TESTING_STANDARDS_JOINED\" | grep -qF 'extractor'"

# =============================================================================
echo ""
echo "=== AC4-A (Green-follow guard, NOT a RED discriminator) — sweep regression oracle ==="
# 798/799/800/949/955 are edited by the AC2 sweep; their own suites are the
# equivalence oracle for those edits (verification design §5).
#
# #951 retired-guard disposition: test-issue-800-doc-assertions.sh and
# test-issue-949-manifest-regen-doc.sh are DELETED by #951 — the sigpipe
# oracle set can no longer stay a regression oracle for suites that no
# longer exist, so both are dropped from the SIBLING_SUITES set below
# (docs/doc-invariant-registry.md dropped/redundant disposition).

SIBLING_SUITES=(
  "$PROJECT_ROOT/tests/test-issue-798-topology-flip.sh"
  "$PROJECT_ROOT/tests/test-issue-799-inert-cleanup.sh"
  "$PROJECT_ROOT/tests/test-issue-955-subagent-background-ban.sh"
  "$PROJECT_ROOT/tests/test-issue-846-doc-assertions.sh"
  "$PROJECT_ROOT/tests/test-issue-848-doc-assertions.sh"
)
for suite in "${SIBLING_SUITES[@]}"; do
  rel="${suite#"$PROJECT_ROOT"/}"
  if [[ -f "$suite" ]]; then
    assert_true "AC4-A: $rel exits 0 (regression oracle for the AC2 sweep)" \
      "bash '$suite' >/dev/null 2>&1"
  else
    assert_true "AC4-A: $rel exists" "false"
  fi
done

# =============================================================================
echo ""
echo "=== AC4-B (informational, NOT a RED discriminator) — grep provenance for this run ==="
# The dev-shell default grep is a Claude Code wrapper function and does not
# exhibit the SIGPIPE race; a green run here is regression evidence only, not
# fix-effect evidence (verification design AC4-B). Recorded, not asserted.

if declare -F grep >/dev/null 2>&1 || type grep 2>/dev/null | grep -qi 'function'; then
  echo "  grep provenance: wrapper (dev-shell function) — regression evidence only, not fix-effect evidence"
else
  echo "  grep provenance: real ($(command -v grep))"
fi

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
