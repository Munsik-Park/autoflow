#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: tests/run-doc-invariants.sh tests/fixtures/doc-invariants.json tests/fixtures/issue-76-anchor-fixture-doc.md
# =============================================================================
# Test: runner --self-test mode (AC-a-3) and anchor-resolution negative
#       coverage for the new section_kind values (AC-f) — Issue #76
# =============================================================================
# .autoflow/issue-76-verification-design.md:
#   AC-a-3 — sample invalidation makes the runner RED (teeth), promoted into
#     `tests/run-doc-invariants.sh --self-test` (feature design
#     `teeth-in-runner`): exhaustive per-entry mutation, credit requires the
#     entry's OWN predicate to report FAIL; an unresolvable anchor after
#     mutation is a non-credit with a diagnostic, never an abort, never a
#     credit (`teeth-mode-anchor-destruction`).
#   AC-f — the new section_kind values resolve the same body the source
#     suite's extractor read: hermetic anchor fixtures — zero-match and
#     multi-match "line" anchors REJECTED AT LOAD TIME; a "block" fixture
#     with a section_end, a heading, and a thematic break all present
#     asserts the stated terminator precedence
#     (section_end > heading > thematic break, terminator EXCLUDED from the
#     body).
#
# This suite is the destination the verification design names directly for
# both criteria ("Hermetic anchor fixtures in tests/test-run-doc-
# invariants.sh" / teeth-mode negative coverage "lands in tests/test-run-
# doc-invariants.sh beside the retained byte-identity and mutator-error
# self-tests"). Per `runner-contract-suite` (feature design), the RETAINED
# legs of tests/test-issue-951-registry.sh are ported into
# tests/test-run-doc-invariants.sh by GREEN as part of the file rename; this
# RED suite is deliberately named test-issue-76-runner-self-test-contract.sh
# rather than pre-emptively renaming/deleting tests/test-issue-951-
# registry.sh, since that rename is the feature design's own file-table
# decision (Files to change > tests/test-run-doc-invariants.sh /
# tests/test-issue-951-registry.sh row) — Test AI does not implement
# renames implementation intent dictates. GREEN or a later Test AI pass
# folds this file's assertions into the renamed
# tests/test-run-doc-invariants.sh; until then this file is the CI-facing
# home and is registered the same way.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUNNER="$PROJECT_ROOT/tests/run-doc-invariants.sh"
FIXDIR="$PROJECT_ROOT/tests/fixtures"
REGISTRY="$FIXDIR/doc-invariants.json"
# shellcheck source=tests/lib/base-ref.sh
source "$SCRIPT_DIR/lib/base-ref.sh"

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

echo "=== Issue #76 — runner --self-test mode (AC-a-3) & anchor negative coverage (AC-f) ==="

# ---------------------------------------------------------------------------
# AC-a-3 — --self-test mode exists and is exhaustive.
# ---------------------------------------------------------------------------
assert_true "AC-a-3: run-doc-invariants.sh --help/usage mentions --self-test" \
  "grep -qF -- '--self-test' '$RUNNER'"

assert_true "AC-a-3: run-doc-invariants.sh --self-test exits 0 against the real registry (every entry demonstrates teeth)" \
  "bash '$RUNNER' --self-test >/tmp/issue76-selftest.out 2>&1"

assert_true "AC-a-3: --self-test reports a Results: line distinct from the default-mode PASS/FAIL line format" \
  "grep -qi 'self-test\|teeth\|mutation' /tmp/issue76-selftest.out 2>/dev/null"

assert_true "AC-a-3: default (no-flag) run-doc-invariants.sh behavior is unchanged (still exits 0/1 on the real registry with no --self-test side effects)" \
  "bash '$RUNNER' >/tmp/issue76-default.out 2>&1; grep -qF 'Results:' /tmp/issue76-default.out"

# ---------------------------------------------------------------------------
# AC-f — anchor-resolution negative coverage, hermetic fixtures.
# ---------------------------------------------------------------------------
assert_true "AC-f: a zero-match 'line' anchor is REJECTED at load time (dangling anchor, not silently skipped)" \
  "out=\$(bash '$RUNNER' '$FIXDIR/issue-76-anchor-zero-match-registry.json' 2>&1); ec=\$?; [ \$ec -ne 0 ] && printf '%s' \"\$out\" | grep -qi 'dangling'"

assert_true "AC-f: a multi-match 'line' anchor is REJECTED at load time (ambiguous anchor, not first-match silently)" \
  "out=\$(bash '$RUNNER' '$FIXDIR/issue-76-anchor-multi-match-registry.json' 2>&1); ec=\$?; [ \$ec -ne 0 ] && printf '%s' \"\$out\" | grep -qi 'ambiguous'"

assert_true "AC-f: a unique 'line' anchor resolves and its predicate evaluates against exactly that one line" \
  "bash '$RUNNER' '$FIXDIR/issue-76-anchor-valid-line-registry.json' >/tmp/issue76-valid-line.out 2>&1; grep -qF 'Results: 2/2 passed' /tmp/issue76-valid-line.out"

assert_true "AC-f: a 'block' anchor with no section_end terminates at the thematic break, excluding the '---' line, and the body does not leak into the next block" \
  "bash '$RUNNER' '$FIXDIR/issue-76-anchor-block-thematic-break-registry.json' >/tmp/issue76-block-thematic.out 2>&1; grep -qF 'Results: 2/2 passed' /tmp/issue76-block-thematic.out"

assert_true "AC-f: a 'block' anchor with an explicit section_end terminates there (precedence over any later heading/thematic-break), excluding the terminator line itself from the body" \
  "bash '$RUNNER' '$FIXDIR/issue-76-anchor-block-explicit-end-registry.json' >/tmp/issue76-block-explicit-end.out 2>&1; grep -qF 'Results: 3/3 passed' /tmp/issue76-block-explicit-end.out"

# ---------------------------------------------------------------------------
# teeth-mode-anchor-destruction — a mutation that destroys a "line"/"block"
# entry's own anchor is a non-credit with a diagnostic, never an abort of
# the whole --self-test run and never a credited FAIL.
#
# GATE:QUALITY FAIL #3 (ledger E14): the prior assertion only grepped for
# the entry id anywhere in the --self-test output, so it passed whether the
# runner printed `TEETH: <id> …` (credited) or `NO-TEETH: <id> …`
# (non-credit) — it could never distinguish the two, which is the entire
# point of this leg. The runner emits the two labels at
# tests/run-doc-invariants.sh:490 (`NO-TEETH: … unmigratable shape …`, the
# literal-overlaps-anchor pre-check) and :543/:546 (`TEETH: …` on a FAIL
# verdict, `NO-TEETH: … has no teeth` otherwise) — ledger E5.1/E5.2.
# `bash '$RUNNER' --self-test` runs once, over the real registry, in the
# runner-self-test-contract.sh suite above; --self-test over a small
# fixture registry additionally exercises each named path hermetically.
# ---------------------------------------------------------------------------
bash "$RUNNER" --self-test "$FIXDIR/issue-76-anchor-valid-line-registry.json" >/tmp/issue76-teeth-line.out 2>&1

assert_true "teeth-mode-anchor-destruction: an ordinary present-literal entry (no anchor overlap) is CREDITED — its mutated copy demonstrates teeth" \
  "grep -qE '^  TEETH: issue-76-fixture-valid-line ' /tmp/issue76-teeth-line.out"

assert_true "teeth-mode-anchor-destruction: an entry whose literal OVERLAPS its own column-1 anchor prefix is a NAMED non-credit, not silently skipped and not falsely credited" \
  "grep -qE '^  NO-TEETH: issue-76-fixture-anchor-overlap-unmigratable ' /tmp/issue76-teeth-line.out"

assert_true "teeth-mode-anchor-destruction: the unmigratable-overlap non-credit names its own reason (literal overlaps its own anchor prefix), distinct from an ineffective-mutation or mutator-error non-credit" \
  "grep -A0 '^  NO-TEETH: issue-76-fixture-anchor-overlap-unmigratable ' /tmp/issue76-teeth-line.out | grep -qi 'overlaps its own column-1 anchor prefix'"

assert_true "teeth-mode-anchor-destruction: the run does not abort on the non-credit entry — the credited entry's own result line is still present in the same run" \
  "grep -qE '^  TEETH: issue-76-fixture-valid-line ' /tmp/issue76-teeth-line.out && grep -qE '^  NO-TEETH: issue-76-fixture-anchor-overlap-unmigratable ' /tmp/issue76-teeth-line.out"

# ---------------------------------------------------------------------------
# AC-f body-equality — the migrated 844 "**Resume procedure**" block
# (GATE:QUALITY FAIL #7, ledger E14: this leg was unimplemented). Compares
# the resolved registry body against the body the DELETED base-ref suite's
# own extractor would have produced, byte-equal MODULO a single trailing
# terminator line (the source `awk` prints the closing `---` before
# exiting; the migrated "block" extractor excludes it — feature design
# `anchor-kinds` > "block" terminator precedence).
#
# Base-ref materialisation follows the precedent in
# tests/test-issue-76-migration-map-total.sh: the OLD extractor's own awk
# (`git show <base>:tests/test-issue-844-doc-assertions.sh` lines ~90-91,
# reproduced verbatim below) is run over the CURRENT
# docs/autoflow-guide.md, since the region's doc CONTENT is not itself
# edited by this migration — only where its test code lives moves. The NEW
# extractor is the runner's own `extract_block` (tests/run-doc-
# invariants.sh:158-170), reproduced verbatim here rather than re-invoked
# (there is no CLI mode that prints one entry's resolved body standalone).
# ---------------------------------------------------------------------------
BASE_REF_AC_F="$(resolve_base_ref)" || BASE_REF_AC_F=""
if [ -n "$BASE_REF_AC_F" ]; then
  OLD_SUITE_SNAPSHOT="$(git -C "$PROJECT_ROOT" show "${BASE_REF_AC_F}:tests/test-issue-844-doc-assertions.sh" 2>/dev/null || true)"
  assert_true "AC-f body-equality pre: base-ref snapshot of the deleted 844 suite resolves" \
    "[ -n '$(printf %s "$OLD_SUITE_SNAPSHOT" | head -c1)' ]"

  GUIDE_MD="$PROJECT_ROOT/docs/autoflow-guide.md"
  OLD_BODY="$(awk '/\*\*Resume procedure\*\*/{flag=1} flag{print} flag && /^---$/{exit}' "$GUIDE_MD")"
  NEW_BODY="$(ANCHOR='**Resume procedure**' ENDPAT='' awk '
    BEGIN { a=ENVIRON["ANCHOR"]; e=ENVIRON["ENDPAT"] }
    !seen && index($0, a) == 1 { seen=1; print; next }
    seen && !stop {
      if (e != "" && index($0, e) == 1) { stop=1; next }
      if ($0 ~ /^#{1,6} +/)            { stop=1; next }
      if ($0 ~ /^---[ \t]*$/)          { stop=1; next }
      print
    }
  ' "$GUIDE_MD")"
  # Modulo a single trailing terminator line: drop OLD_BODY's last line if
  # (and only if) it is the thematic break the migrated extractor excludes.
  # (awk, not `sed '$ {...}'` — the GNU block-address form is not portable
  # to the BSD sed on this platform.)
  OLD_BODY_MODULO="$(printf '%s\n' "$OLD_BODY" | awk '
    NR > 1 { print prev }
    { prev = $0 }
    END { if (prev !~ /^---[ \t]*$/) print prev }
  ')"

  assert_true "AC-f body-equality: the migrated 'block' body for 844's Resume-procedure region is byte-equal to the deleted suite's own extractor, modulo the trailing terminator line" \
    "[ \"\$OLD_BODY_MODULO\" = \"\$NEW_BODY\" ]"

  # Safety companion (feature design `anchor-kinds`): no migrated predicate
  # for this block may depend on the terminator line's own content — the
  # modulo comparison above is only safe if nothing asserts on it.
  assert_true "AC-f body-equality safety: no 844 Resume-procedure registry entry's literal references the terminator line's content ('---')" \
    "! jq -e '.invariants[] | select(.section == \"**Resume procedure**\") | select((.literal // \"\") | test(\"^---\"))' '$REGISTRY' >/dev/null 2>&1"
else
  assert_true "AC-f body-equality: base ref resolvable (skipped leg — no base ref)" "false"
fi

# ---------------------------------------------------------------------------
# AC-c-3 clause 2 — every RETAINED scenario document satisfies at least one
# of the five `manual-doc-closure` dependent kinds (GATE:QUALITY FAIL #7,
# ledger E14: unimplemented). The five kinds, per the feature design:
#   1. a registry entry targets it (id path match on the document file);
#   2. a surviving suite asserts on it (content grep for the basename);
#   3. a docs/maintained-docs.md row registers it;
#   4. a prose document (CLAUDE.md, docs/**) cites it as evidence;
#   5. a RETAINED scenario document cites it.
# A workflow `paths:` entry is explicitly NOT a dependent (manual-doc-
# closure), so it is deliberately not checked here.
# ---------------------------------------------------------------------------
RETAINED_DOCS=(
  issue-27 issue-42 issue-51 issue-52 issue-55 issue-56 issue-59 issue-62
  issue-67 issue-71 issue-795 issue-798 issue-799 issue-800 issue-846
  issue-847 issue-848 issue-985
)
for name in "${RETAINED_DOCS[@]}"; do
  docfile="tests/manual/${name}-manual-scenarios.md"
  [ -f "$PROJECT_ROOT/$docfile" ] || continue
  has_dependent=false
  # Kind 1: registry entry names the document as its file.
  if jq -e --arg f "$docfile" '.invariants[] | select(.file == $f)' "$REGISTRY" >/dev/null 2>&1; then
    has_dependent=true
  fi
  # Kind 2: a surviving suite content-references the document's basename.
  base="${name}-manual-scenarios"
  if grep -rl -- "$base" "$PROJECT_ROOT/tests" 2>/dev/null | grep -vF "/$docfile" | grep -q .; then
    has_dependent=true
  fi
  # Kind 3: a docs/maintained-docs.md row registers it.
  if grep -qF "$base" "$PROJECT_ROOT/docs/maintained-docs.md" 2>/dev/null; then
    has_dependent=true
  fi
  # Kind 4: a prose document cites it as evidence.
  if grep -rlF -- "$base" "$PROJECT_ROOT/CLAUDE.md" "$PROJECT_ROOT/docs" 2>/dev/null | grep -q .; then
    has_dependent=true
  fi
  # Kind 5: a retained sibling scenario document cites it.
  if grep -rlF -- "$base" "$PROJECT_ROOT/tests/manual" 2>/dev/null | grep -vF "/$docfile" | grep -q .; then
    has_dependent=true
  fi
  assert_true "AC-c-3 clause 2: retained scenario document satisfies >=1 of the five dependent kinds — $name" "$has_dependent"
done

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
