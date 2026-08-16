#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/ledger/ledger-entry-id.sh CLAUDE.md docs/teammate-contracts.md
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: decision-ledger entry-ID uniqueness — allocation (`next`) + detection
#       (`check`) script behavior (Issue #97)
# =============================================================================
# Permanent, subject-named standing suite (NOT issue-numbered per GATE:PLAN
# reflection E12(a), .autoflow/issue-97-ledger.md) — the script and its
# behavior contract are permanent once shipped, so this suite is never
# retired. The cycle-scoped registration delta (this suite's own CI wiring)
# lives separately in tests/test-issue-97-ledger-id-registration.sh, deleted
# before DELIVER per docs/doc-invariant-registry.md §1/§2.
#
# Verification design: .autoflow/issue-97-verification-design.md — AC-next-*,
# AC-check-*, AC-autofix-marker-preserved.
#
# AC-autofix-marker-preserved ORACLE LIMITATION (GATE:PLAN E12(c)): the
# guide's marker-scoped-then-positional SELECTION algorithm
# (docs/autoflow-guide.md > VERIFY > Green-tree register > Entry grammar) is
# prose executed by a spawned AI agent, not by any shipped script — grepping
# the repo for a reader of that algorithm finds none (feature design §1). This
# suite therefore cannot drive that selection as code; it asserts only the
# parts realized in this script and in a plain grep — that `check` does not
# flag `review-autofix`/level-3 record headings as duplicate or unidentified,
# and that a grep-based stand-in for the HANDOFF cap's `review-autofix` count
# predicate (docs/autoflow-guide.md step 6.5) is unaffected by the level-2 ID
# prefix. Non-interference of the guide's own selection prose with a level-2
# heading is a documented property (feature design entry-id-grammar >
# "The green-tree marker scan never sees it"), not one this suite drives.
#
# RED expectation: scripts/ledger/ledger-entry-id.sh does not exist yet, so
# every `next`/`check` invocation below fails with "No such file or
# directory" (bash exit 127) rather than the intended exit codes — this is
# the missing-behavior reason, not a harness crash: every assertion routes
# through run_next/run_check, which capture actual stdout/stderr/exit and
# compare against the intended contract, so a 127 simply mismatches every
# expected exit/stdout/stderr shape uniformly.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PROJECT_ROOT/scripts/ledger/ledger-entry-id.sh"

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

# run_next <ledger-path> <namespace> -> sets NEXT_OUT / NEXT_ERR / NEXT_EXIT
run_next() {
  local ledger="$1" ns="$2"
  NEXT_OUT=$(bash "$SCRIPT" next "$ledger" "$ns" 2>/tmp/ledger-next-err.$$)
  NEXT_EXIT=$?
  NEXT_ERR=$(cat /tmp/ledger-next-err.$$ 2>/dev/null)
  rm -f /tmp/ledger-next-err.$$
}

# run_check <ledger-path...> -> sets CHECK_OUT / CHECK_ERR / CHECK_EXIT
run_check() {
  CHECK_OUT=$(bash "$SCRIPT" check "$@" 2>/tmp/ledger-check-err.$$)
  CHECK_EXIT=$?
  CHECK_ERR=$(cat /tmp/ledger-check-err.$$ 2>/dev/null)
  rm -f /tmp/ledger-check-err.$$
}

TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

echo "=== Issue #97 — ledger-entry-id.sh: next / check ==="

# ---------------------------------------------------------------------------
echo ""
echo "=== AC-next-from-file ==="

MISSING_LEDGER="$TMP_ROOT/missing-ledger.md"
run_next "$MISSING_LEDGER" O
assert_true "AC-next-from-file: missing file -> O1, exit 0" \
  '[ "$NEXT_EXIT" = "0" ] && [ "$NEXT_OUT" = "O1" ]'

FILE_LEDGER="$TMP_ROOT/from-file-ledger.md"
cat > "$FILE_LEDGER" <<'EOF'
# Decision Ledger — issue #9

## O1 — first decision (cycle 1, GATE:PLAN)

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, GATE:PLAN

## O3 — third decision (cycle 1, VERIFY)

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, VERIFY
EOF
run_next "$FILE_LEDGER" O
assert_true "AC-next-from-file: highest existing O serial (O3) + 1 -> O4" \
  '[ "$NEXT_EXIT" = "0" ] && [ "$NEXT_OUT" = "O4" ]'

# ---------------------------------------------------------------------------
echo ""
echo "=== AC-next-namespace-isolated ==="

MIXED_LEDGER="$TMP_ROOT/mixed-ledger.md"
cat > "$MIXED_LEDGER" <<'EOF'
# Decision Ledger — issue #9

## E5 — legacy entry (cycle 1, ARCHITECT)

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, ARCHITECT

## O2 — orchestrator entry (cycle 1, GATE:PLAN)

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, GATE:PLAN

## F7 — facilitator entry (cycle 1, ARCHITECT)

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, ARCHITECT

## O1 — earlier orchestrator entry (cycle 1, GATE:HYPOTHESIS)

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, GATE:HYPOTHESIS
EOF
run_next "$MIXED_LEDGER" O
assert_true "AC-next-namespace-isolated: O allocation (O2 max) ignores E5/F7 -> O3" \
  '[ "$NEXT_EXIT" = "0" ] && [ "$NEXT_OUT" = "O3" ]'
run_next "$MIXED_LEDGER" F
assert_true "AC-next-namespace-isolated: F allocation (F7 max) ignores E5/O2 -> F8" \
  '[ "$NEXT_EXIT" = "0" ] && [ "$NEXT_OUT" = "F8" ]'

# ---------------------------------------------------------------------------
echo ""
echo "=== AC-next-rejects-namespace ==="

run_next "$FILE_LEDGER" E
assert_true "AC-next-rejects-namespace: namespace E (legacy, not issuable) exits 2, empty stdout" \
  '[ "$NEXT_EXIT" = "2" ] && [ -z "$NEXT_OUT" ]'
run_next "$FILE_LEDGER" X
assert_true "AC-next-rejects-namespace: namespace X (unrecognized) exits 2, empty stdout" \
  '[ "$NEXT_EXIT" = "2" ] && [ -z "$NEXT_OUT" ]'
NEXT_OUT=$(bash "$SCRIPT" next "$FILE_LEDGER" 2>/tmp/ledger-next-noarg-err.$$)
NEXT_EXIT=$?
NEXT_ERR=$(cat /tmp/ledger-next-noarg-err.$$ 2>/dev/null)
rm -f /tmp/ledger-next-noarg-err.$$
assert_true "AC-next-rejects-namespace: missing namespace argument exits 2, empty stdout" \
  '[ "$NEXT_EXIT" = "2" ] && [ -z "$NEXT_OUT" ]'

# ---------------------------------------------------------------------------
echo ""
echo "=== AC-next-sequence-two-writer (real-tree composition oracle) ==="
# Reproduces the reported failure sequence against ONE real on-disk ledger,
# with no state carried between calls other than the file itself: O allocates
# and appends, then F allocates and appends a run of entries, then O
# allocates again with no memory of its own prior serial. A writer that reads
# the file once and increments locally for the rest of a batch would pass
# every per-call AC-next-from-file assertion above and still fail here.

SEQ_LEDGER="$TMP_ROOT/two-writer-ledger.md"
rm -f "$SEQ_LEDGER"

append_entry() {
  local id="$1"
  cat >> "$SEQ_LEDGER" <<EOF

## ${id} — sequence step (cycle 1, TEST)

- Decision: step ${id}
- Grounds: sequence fixture
- Authority: AC-next-sequence-two-writer
- Cycle/Phase: cycle 1, TEST
EOF
}

seq_ok=1
seq_ids=""

run_next "$SEQ_LEDGER" O
[ "$NEXT_EXIT" = "0" ] || seq_ok=0
[ "$NEXT_OUT" = "O1" ] || seq_ok=0
append_entry "$NEXT_OUT"; seq_ids="$seq_ids $NEXT_OUT"
run_check "$SEQ_LEDGER"; [ "$CHECK_EXIT" = "0" ] || seq_ok=0

for want in F1 F2 F3; do
  run_next "$SEQ_LEDGER" F
  [ "$NEXT_EXIT" = "0" ] || seq_ok=0
  [ "$NEXT_OUT" = "$want" ] || seq_ok=0
  append_entry "$NEXT_OUT"; seq_ids="$seq_ids $NEXT_OUT"
  run_check "$SEQ_LEDGER"; [ "$CHECK_EXIT" = "0" ] || seq_ok=0
done

run_next "$SEQ_LEDGER" O
[ "$NEXT_EXIT" = "0" ] || seq_ok=0
[ "$NEXT_OUT" = "O2" ] || seq_ok=0
append_entry "$NEXT_OUT"; seq_ids="$seq_ids $NEXT_OUT"
run_check "$SEQ_LEDGER"; [ "$CHECK_EXIT" = "0" ] || seq_ok=0

# no identifier collides with any other in the sequence
dup_count=$(printf '%s\n' $seq_ids | sort | uniq -d | wc -l | tr -d ' ')
[ "$dup_count" = "0" ] || seq_ok=0

TESTS=$((TESTS + 1))
if [ "$seq_ok" = "1" ]; then
  echo "  PASS: AC-next-sequence-two-writer: O,F,F,F,O interleave allocates $seq_ids with no collision, check exits 0 throughout"
  PASS=$((PASS + 1))
else
  echo "  FAIL: AC-next-sequence-two-writer: interleaved allocation sequence broke (ids: $seq_ids)"
  FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
echo ""
echo "=== AC-check-duplicate ==="

DUP_LEDGER="$TMP_ROOT/dup-ledger.md"
cat > "$DUP_LEDGER" <<'EOF'
# Decision Ledger — issue #9

## O1 — first decision (cycle 1, GATE:PLAN)

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, GATE:PLAN

## O1 — a different title for the same collided identifier (cycle 1, VERIFY)

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, VERIFY
EOF
run_check "$DUP_LEDGER"
assert_true "AC-check-duplicate: exits 1 on a duplicated O1 identifier" \
  '[ "$CHECK_EXIT" = "1" ]'
assert_true "AC-check-duplicate: reports duplicate-id: O1 with both line numbers" \
  'printf "%s" "$CHECK_ERR" | grep -qE "duplicate-id: O1 \(lines 3,10\)"'

# ---------------------------------------------------------------------------
echo ""
echo "=== AC-check-unidentified ==="

UNIDENT_LEDGER="$TMP_ROOT/unident-ledger.md"
cat > "$UNIDENT_LEDGER" <<'EOF'
# Decision Ledger — issue #9

## Entry 3 — legacy unnumbered form

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, GATE:PLAN

## A bare prose heading with no identifier

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, VERIFY
EOF
run_check "$UNIDENT_LEDGER"
assert_true "AC-check-unidentified: exits 1 on unidentified level-2 headings" \
  '[ "$CHECK_EXIT" = "1" ]'
assert_true "AC-check-unidentified: reports unidentified-entry for 'Entry 3' heading (line 3)" \
  'printf "%s" "$CHECK_ERR" | grep -qE "unidentified-entry: line 3:.*Entry 3"'
assert_true "AC-check-unidentified: reports unidentified-entry for the bare prose heading (line 10)" \
  'printf "%s" "$CHECK_ERR" | grep -qE "unidentified-entry: line 10:.*bare prose heading"'

# ---------------------------------------------------------------------------
echo ""
echo "=== unidentified-entry sanitize/truncate bound (VERIFY step-3 leg) ==="
# check_one's sanitize() strips control characters and truncates the echoed
# heading to 117 chars + "..." once the raw line exceeds 120 -- load-bearing
# because the hook's advisory step (Section 1c) surfaces this same text in a
# stderr warning line, so an unbounded/control-char-carrying echo would leak
# into that warning verbatim.
SANITIZE_LEDGER="$TMP_ROOT/sanitize-ledger.md"
HEADING_LINE="## Unidentified heading$(printf '\x01')with an embedded control character and a very long trailing description that pushes this single heading line comfortably past the one hundred twenty character truncation bound enforced by the ledger sanitize helper for check"
{
  printf '%s\n' "# Decision Ledger — issue #9"
  printf '\n'
  printf '%s\n' "$HEADING_LINE"
  printf '\n'
  printf '%s\n' "- Decision: x"
  printf '%s\n' "- Grounds: y"
  printf '%s\n' "- Authority: z"
  printf '%s\n' "- Cycle/Phase: cycle 1, GATE:PLAN"
} > "$SANITIZE_LEDGER"
run_check "$SANITIZE_LEDGER"
assert_true "sanitize: exits 1 on the unidentified over-long/control-char heading" \
  '[ "$CHECK_EXIT" = "1" ]'
assert_true "sanitize: unidentified-entry text is truncated to exactly 117 chars + '...' (line 3)" \
  'printf "%s" "$CHECK_ERR" | grep -qE "^unidentified-entry: line 3: .{117}\.\.\.$"'
assert_true "sanitize: no raw control byte survives in check'\''s stderr output" \
  '[ -z "$(printf "%s" "$CHECK_ERR" | LC_ALL=C tr -d "[:print:]\n")" ]'

# ---------------------------------------------------------------------------
echo ""
echo "=== AC-check-clean ==="

CLEAN_LEDGER="$TMP_ROOT/clean-ledger.md"
cat > "$CLEAN_LEDGER" <<'EOF'
# Decision Ledger — issue #9

## E1 — legacy entry (cycle 1, ARCHITECT)

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, ARCHITECT

## O1 — orchestrator entry (cycle 1, GATE:PLAN)

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, GATE:PLAN

## F1 — facilitator entry (cycle 1, ARCHITECT)

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, ARCHITECT
EOF
run_check "$CLEAN_LEDGER"
assert_true "AC-check-clean: exits 0 on distinct E/O/F identifiers" \
  '[ "$CHECK_EXIT" = "0" ]'
assert_true "AC-check-clean: emits no stderr" \
  '[ -z "$CHECK_ERR" ]'

# ---------------------------------------------------------------------------
echo ""
echo "=== AC-check-ignores-record-entries (fixture leg) ==="

RECORD_LEDGER="$TMP_ROOT/record-ledger.md"
cat > "$RECORD_LEDGER" <<'EOF'
# Decision Ledger — issue #9

## O1 — orchestrator entry (cycle 1, GATE:PLAN)

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, GATE:PLAN

### green-tree | cycle: 1 | runner: VERIFY step 1

- tree: abc123
- outcome: passed

### green-tree-use | cycle: 1 | runner: REFINE step 2

- inherited: abc123
- outcome: reused

### verify-detection | cycle: 1 | runner: VERIFY step 3

- detected: none

## F1 — facilitator entry (cycle 1, ARCHITECT)

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, ARCHITECT
EOF
run_check "$RECORD_LEDGER"
assert_true "AC-check-ignores-record-entries: title + green-tree/green-tree-use/verify-detection level-3 entries never produce a defect (exit 0)" \
  '[ "$CHECK_EXIT" = "0" ]'
assert_true "AC-check-ignores-record-entries: emits no stderr" \
  '[ -z "$CHECK_ERR" ]'

# ---------------------------------------------------------------------------
echo ""
echo "=== AC-check-usage ==="

CHECK_OUT=$(bash "$SCRIPT" check 2>/tmp/ledger-check-noarg-err.$$)
CHECK_EXIT=$?
CHECK_ERR=$(cat /tmp/ledger-check-noarg-err.$$ 2>/dev/null)
rm -f /tmp/ledger-check-noarg-err.$$
assert_true "AC-check-usage: no path argument exits 2" \
  '[ "$CHECK_EXIT" = "2" ]'
run_check "$TMP_ROOT/does-not-exist-ledger.md"
assert_true "AC-check-usage: nonexistent path exits 2 (distinct from the exit-1 defect outcome)" \
  '[ "$CHECK_EXIT" = "2" ]'

# ---------------------------------------------------------------------------
echo ""
echo "=== check <ledger-path> is single-argument (VERIFY step-3 leg; EXPECTED RED until Developer AI removes the variadic loop) ==="
# Feature design's own Command interface ("check <ledger-path> -> ... ; 0 | 1 | 2",
# singular) and detection-script ("Scope is one ledger file passed by path") both
# scope `check` to exactly ONE ledger; no caller (the hook's advisory step, the
# facilitator prompts) ever passes more than one. A second path is therefore a
# usage error (exit 2), the same disposition as no path at all -- NOT an
# aggregate multi-file scan. VERIFY step 3 (issue #97) found the shipped script
# accepts `check <path>...` variadically with no test and no AC behind it; this
# leg is the removal-tracking test, routed by the team lead as "remove, not
# keep" -- it is expected to stay Red until that removal lands.
run_check "$CLEAN_LEDGER" "$FILE_LEDGER"
assert_true "check: a SECOND ledger-path argument is a usage error (exit 2), matching the documented single-argument interface" \
  '[ "$CHECK_EXIT" = "2" ]'

# ---------------------------------------------------------------------------
echo ""
echo "=== AC-autofix-marker-preserved (real-tree composition oracle; see ORACLE LIMITATION header note) ==="

MARKER_LEDGER="$TMP_ROOT/marker-ledger.md"
cat > "$MARKER_LEDGER" <<'EOF'
# Decision Ledger — issue #9

## O1 — earlier decision (cycle 1, GATE:PLAN)

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, GATE:PLAN

### green-tree | cycle: 1 | runner: VERIFY step 1

- tree: abc123
- outcome: passed

### green-tree-use | cycle: 1 | runner: REFINE step 2

- inherited: abc123
- outcome: reused

### verify-detection | cycle: 1 | runner: VERIFY step 3

- detected: none

## O2 — auto-triggered review-response entry (cycle 1, HANDOFF) [review-autofix]

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, HANDOFF

## F1 — facilitator entry (cycle 1, ARCHITECT)

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, ARCHITECT
EOF

# Baseline count BEFORE the level-2 entries existed (a ledger holding only the
# level-3 record entries + the marker line, no other level-2 entries) —
# feature design's own before/after comparison.
BASELINE_LEDGER="$TMP_ROOT/marker-baseline-ledger.md"
cat > "$BASELINE_LEDGER" <<'EOF'
### green-tree | cycle: 1 | runner: VERIFY step 1

- tree: abc123
- outcome: passed

### green-tree-use | cycle: 1 | runner: REFINE step 2

- inherited: abc123
- outcome: reused

### verify-detection | cycle: 1 | runner: VERIFY step 3

- detected: none

## O2 — auto-triggered review-response entry (cycle 1, HANDOFF) [review-autofix]

- Decision: x
- Grounds: y
- Authority: z
- Cycle/Phase: cycle 1, HANDOFF
EOF

run_check "$MARKER_LEDGER"
assert_true "AC-autofix-marker-preserved: check does not flag the review-autofix heading or the level-3 record entries (exit 0)" \
  '[ "$CHECK_EXIT" = "0" ]'

# Stand-in for the HANDOFF cap's count predicate (docs/autoflow-guide.md step
# 6.5: "count of consecutive review-autofix-marked ledger entries") — a
# grep -c for the literal on level-2 heading lines, before/after the level-2
# ID-grammar entries exist around it. The ID prefix + em-dash title must not
# change the count.
before_count=$(grep -c '^## .*\[review-autofix\]' "$BASELINE_LEDGER")
after_count=$(grep -c '^## .*\[review-autofix\]' "$MARKER_LEDGER")
assert_true "AC-autofix-marker-preserved: review-autofix count predicate unchanged by the ID-grammar prefix (before=$before_count, after=$after_count)" \
  '[ "$before_count" = "1" ] && [ "$after_count" = "1" ]'

# ---------------------------------------------------------------------------
echo ""
echo "=== AC-rule-text / writer-namespace — single-home sweep ==="
# feature design writer-namespace > "Single home for the mapping": the
# writer -> namespace table (Orchestrator=O / Facilitator delegate=F) has
# exactly one documentary home, CLAUDE.md > Decision Ledger. No second
# document restates the table itself (docs/teammate-contracts.md cites it,
# it does not carry the letter). This is a permanent property of the doc
# tree, not expressible as a single-file registry entry (the registry
# schema is one file per entry), so it lives here as a repo-wide sweep.

assert_true "single-home: CLAUDE.md carries the Orchestrator -> O namespace row" \
  "grep -qE '\\| *Orchestrator *\\| *\`O\`' '$PROJECT_ROOT/CLAUDE.md'"
assert_true "single-home: CLAUDE.md carries the Facilitator delegate -> F namespace row" \
  "grep -qE '\\| *Facilitator delegate *\\| *\`F\`' '$PROJECT_ROOT/CLAUDE.md'"
assert_false "single-home: no OTHER tracked markdown doc restates the namespace table rows" \
  "git -C '$PROJECT_ROOT' ls-files '*.md' | grep -v '^CLAUDE.md$' | grep -v '^\\.autoflow/' | xargs -I{} grep -lE '\\| *(Orchestrator|Facilitator delegate) *\\| *\`[OF]\`' {} 2>/dev/null | grep -q ."

# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
