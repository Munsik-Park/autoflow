#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/workflows/architect-deliberation.js tests/lib/architect-turn-harness.mjs scripts/architect/record-discipline.sh tests/fixtures/issue-166-record-residue.md tests/fixtures/issue-166-record-clean.md docs/autoflow-guide.md docs/teammate-contracts.md setup/gen-manifest-hashes.sh
# lane: cycle-scoped
# retire-with: #166
# cycle-arm: #166
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: issue #166 — ARCHITECT deliberation cost structure
# =============================================================================
# #595 measured the turns after the first exchange at 62% of the deliberation's
# wall time: every fresh turn re-read both documents in full, accepting turns
# edited as much as countering ones, closed register entries were rendered as
# work and re-closed, and the Record rules existed only as prompt text. The
# script-side changes under test:
#   1. counter substance — a counter from the third turn on names what it
#      changes (`changes`) or is recorded as an `observation`;
#   2. closed entries render by name only; the disposition-name enum is the
#      open set and a disposition on a closed name is ignored;
#   3. each side snapshots at its turn start and its next turn reads by diff;
#   4. scripts/architect/record-discipline.sh — the mechanical Record-rules
#      check, reached from every authoring prompt and shipped in the bundle.
# Issue item 4 (emit-cycle-digest.sh reading `rounds` from the Workflow
# result) is out of this repository: the script was removed here in #71
# (a40e752) and lives in Munsik-Park/autoflow-codex.
#
# Halves:
#   1. BEHAVIOR — the #166 scenarios in tests/lib/architect-turn-harness.mjs
#      run the real script against the shipped config.
#   2. CHECKER — record-discipline.sh reports each residue class once per line
#      on the residue fixture, is clean on the clean fixture, and exits 2 on
#      usage errors.
#   3. STATICS — the schema, status enum, rule literals and the bundle row.
#   4. DOCS — the guide's Record rules and the Facilitator contract state the
#      four rules.
#
# CYCLE-SCOPED by construction: the behavioral half re-reads the harness the
# standing #152 suite executes on every run, so the contract stays protected
# after this suite retires; the literals, fixtures and doc wording verify this
# issue's acceptance once.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
allow_list=(
  ".claude/workflows/architect-deliberation.js"
  "tests/lib/architect-turn-harness.mjs"
  "scripts/architect/record-discipline.sh"
  "tests/fixtures/issue-166-record-residue.md"
  "tests/fixtures/issue-166-record-clean.md"
  "docs/autoflow-guide.md"
  "docs/teammate-contracts.md"
  "setup/gen-manifest-hashes.sh"
)
WF="$PROJECT_ROOT/${allow_list[0]}"
HARNESS="$PROJECT_ROOT/${allow_list[1]}"
CHECKER="$PROJECT_ROOT/${allow_list[2]}"
RESIDUE="$PROJECT_ROOT/${allow_list[3]}"
CLEAN="$PROJECT_ROOT/${allow_list[4]}"
GUIDE="$PROJECT_ROOT/${allow_list[5]}"
CONTRACTS="$PROJECT_ROOT/${allow_list[6]}"
GEN="$PROJECT_ROOT/${allow_list[7]}"

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
failc() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# -----------------------------------------------------------------------------
# 1. Behavior — the harness runs the real script; the #166 scenarios must PASS.
# -----------------------------------------------------------------------------
echo "== behavior: #166 harness scenarios =="
if command -v node >/dev/null 2>&1; then
  sim_out=$(node "$HARNESS" "$PROJECT_ROOT" 2>&1)
  sim_rc=$?
  printf '%s\n' "$sim_out" | grep "issue-166" | sed 's/^/    /'
  for sc in issue-166-late-counter-without-changes-is-observation \
            issue-166-late-counter-with-changes-stays-open \
            issue-166-first-exchange-counter-exempt \
            issue-166-closed-entry-renders-name-only \
            issue-166-disposition-on-closed-entry-ignored \
            issue-166-disposition-name-enum-is-open-set \
            issue-166-snapshot-first-then-read-by-diff \
            issue-166-resume-turn-reads-by-diff-and-binds-substance \
            issue-166-observation-only-register-all-accept-resumable \
            issue-166-observation-not-escalation-ground \
            issue-166-ac-mint-stays-open \
            issue-166-record-discipline-check-in-authoring-prompts; do
    if printf '%s\n' "$sim_out" | grep -qx "$sc PASS"; then
      pass "behavior: $sc"
    else
      failc "behavior: $sc did not PASS"
    fi
  done
  if [ "$sim_rc" = "0" ]; then
    pass "behavior: harness exit 0 (no scenario regressed)"
  else
    failc "behavior: harness exit $sim_rc"
  fi
else
  failc "behavior: node is required to execute the workflow harness and is not installed"
fi

# -----------------------------------------------------------------------------
# 2. Checker — record-discipline.sh over the two fixtures.
# -----------------------------------------------------------------------------
echo "== checker: record-discipline.sh =="
res_out=$(bash "$CHECKER" check "$RESIDUE" 2>/dev/null)
res_rc=$?
if [ "$res_rc" = "1" ]; then
  pass "checker: residue fixture exits 1"
else
  failc "checker: residue fixture exit $res_rc (want 1)"
fi
for cls in register-section round-history measurement-log command-output; do
  if printf '%s\n' "$res_out" | grep -q ": $cls: "; then
    pass "checker: residue fixture reports $cls"
  else
    failc "checker: residue fixture does not report $cls"
  fi
done
# One report per (line, pattern name): the line matching three round-history grammars is one hit.
n13=$(printf '%s\n' "$res_out" | grep -c ":13: round-history: ")
if [ "$n13" = "1" ]; then
  pass "checker: a line matching several grammars of one class is reported once"
else
  failc "checker: line 13 reported $n13 times (want 1)"
fi
if printf '%s\n' "$res_out" | grep -qE '^record-discipline: [0-9]+ hit\(s\)$'; then
  pass "checker: residue summary line carries the hit count"
else
  failc "checker: residue summary line missing"
fi
clean_out=$(bash "$CHECKER" check "$CLEAN" 2>/dev/null)
clean_rc=$?
if [ "$clean_rc" = "0" ] && [ "$clean_out" = "record-discipline: clean" ]; then
  pass "checker: clean fixture exits 0 with the clean summary"
else
  failc "checker: clean fixture exit $clean_rc / '$clean_out'"
fi
bash "$CHECKER" check >/dev/null 2>&1; u1=$?
bash "$CHECKER" check "$PROJECT_ROOT/tests/fixtures/issue-166-does-not-exist.md" >/dev/null 2>&1; u2=$?
bash "$CHECKER" >/dev/null 2>&1; u3=$?
if [ "$u1" = "2" ] && [ "$u2" = "2" ] && [ "$u3" = "2" ]; then
  pass "checker: no file / missing file / no subcommand exit 2"
else
  failc "checker: usage exits $u1 $u2 $u3 (want 2 2 2)"
fi

# -----------------------------------------------------------------------------
# 3. Statics — schema, status enum, rule literals, bundle row.
# -----------------------------------------------------------------------------
echo "== statics: script and bundle =="
if grep -q "required: \['agenda', 'locator', 'argument', 'changes'\]" "$WF"; then
  pass "statics: COUNTER requires changes"
else
  failc "statics: COUNTER does not require changes"
fi
if grep -q "enum: \['open', 'agreed', 'rejected', 'observation'\]" "$WF"; then
  pass "statics: REGISTER_ENTRY status enum carries observation"
else
  failc "statics: REGISTER_ENTRY status enum lacks observation"
fi
if grep -q "const substanceRequired = (t) => resume || t > 2" "$WF"; then
  pass "statics: the substance rule binds from the third turn and on every resume turn"
else
  failc "statics: substanceRequired predicate missing or reshaped"
fi
if grep -q "const renderClosedNames" "$WF" && ! grep -q "const renderSettled" "$WF"; then
  pass "statics: closed entries render by name; the resume-only full render is retired"
else
  failc "statics: renderClosedNames missing or renderSettled survives"
fi
if grep -q "disposition ignored (entry not open" "$WF" && grep -q "const turnSchemaFor" "$WF"; then
  pass "statics: closed-name dispositions are ignored and the turn schema offers the open names"
else
  failc "statics: closed-name disposition guard or turnSchemaFor missing"
fi
if grep -q "architect-snapshot-\${side}-feature-design.md" "$WF" && grep -q "Read by diff, not in full" "$WF" && grep -q "Snapshot first" "$WF"; then
  pass "statics: snapshot paths and the two read rules are in the script"
else
  failc "statics: snapshot paths or read rules missing"
fi
if grep -q "scripts/architect/record-discipline.sh check \${feature} \${verif}" "$WF"; then
  pass "statics: RECORD_DISCIPLINE_RULE names the checker over both documents"
else
  failc "statics: RECORD_DISCIPLINE_RULE does not name the checker"
fi
if grep -q 'emit_row "scripts/architect/record-discipline.sh"' "$GEN"; then
  pass "statics: the checker is a root-layer bundle row"
else
  failc "statics: the checker is not registered in the manifest generator"
fi
if [ -x "$CHECKER" ]; then
  pass "statics: the checker is executable"
else
  failc "statics: the checker is not executable"
fi

# -----------------------------------------------------------------------------
# 4. Docs — the guide's Record rules and the Facilitator contract.
# -----------------------------------------------------------------------------
echo "== docs: Record rules and Facilitator contract =="
for phrase in "Open entries in full, closed entries by name" \
              "A late counter names what it changes" \
              "Read by diff, not in full" \
              "The check is mechanical" \
              "Record-discipline advisory (orchestrator-side"; do
  if grep -qF "$phrase" "$GUIDE"; then
    pass "docs: guide states '$phrase'"
  else
    failc "docs: guide lacks '$phrase'"
  fi
done
for phrase in '`{ agenda, locator, argument, changes }`' \
              "Counter substance" \
              "rendered by **name only**" \
              "a closed name is ignored, never re-applied" \
              "scripts/architect/record-discipline.sh check" \
              "Read by diff"; do
  if grep -qF "$phrase" "$CONTRACTS"; then
    pass "docs: contract states '$phrase'"
  else
    failc "docs: contract lacks '$phrase'"
  fi
done

echo
echo "=============================================="
echo "PASS: $PASS  FAIL: $FAIL"
echo "=============================================="
[ "$FAIL" = "0" ]
