#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .gitignore .autoflow/ scripts/test/
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: no cycle-layer asset has entered the merged tree — the ignore rule and
#       the index agree about `.autoflow/issue-{N}-local/`.
# =============================================================================
# STANDING suite (`automated / standing: cross-file`), subject-named, no issue
# number — docs/autoflow-guide.md > RED > Naming. This file is AC3's confirming
# means as ADR-0024 D2 names it: "One standing tracked-file predicate over the
# declared prefix ... the defect it catches is a cycle asset entering the merged
# tree — the ignore rule and the index disagreeing about the prefix, which a
# `.gitignore` edit three cycles from now would cause — and that defect surfaces
# only after merge, where no per-PR relation can see it."
#
# THE SUBJECT IS THE INDEX, NOT THE WORKTREE (feature design P5, read from
# ADR-0024:220-225). `.gitignore` already keeps the prefix out of the default
# add path, so a worktree predicate re-checks what the ignore rule does; only
# the index can witness the two disagreeing.
#
# THE LOGIC IS NOT HERE. It lives in `scripts/test/check-cycle-layer-index.sh`,
# which this suite calls, so the predicate is invocable against a fixture root
# and its exit-code contract is exercisable on its own
# (.autoflow/issue-228-local/ac4-index-predicate-contract.sh, this cycle).
#
# WHY A `run:` STEP IS NOT ENOUGH ON ITS OWN: the declared form is the only one
# whose trigger coverage is asserted, by
# tests/test-workflow-trigger-conformance.sh's registration-effectiveness
# oracle. A bare `paths:` entry plus an unconditional lint step is conformant
# but unpinned — a later cycle drops the entry, the check stops being reachable
# for the one diff class it exists for, and every run stays green.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PREDICATE="$PROJECT_ROOT/scripts/test/check-cycle-layer-index.sh"

PASS=0; FAIL=0
pass()  { echo "  PASS: $1"; PASS=$((PASS + 1)); }
failc() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "=== cycle-layer store: the ignore rule and the index agree about .autoflow/issue-{N}-local/ ==="

# ---------------------------------------------------------------------------
# 1. The ignore side of the agreement.
# ---------------------------------------------------------------------------
if git -C "$PROJECT_ROOT" check-ignore -q -- '.autoflow/issue-0-local/probe.sh'; then
  pass "IGNORE-RULE: .gitignore excludes a path under the declared cycle-layer prefix from the default add path"
else
  failc "IGNORE-RULE: .gitignore no longer excludes .autoflow/issue-{N}-local/** — the cycle layer's storage rule (ADR-0024 D2) has no enforcement left"
fi

# ---------------------------------------------------------------------------
# 2. The index side — the predicate's verdict over this repository.
# ---------------------------------------------------------------------------
if [ ! -x "$PREDICATE" ] && [ ! -f "$PREDICATE" ]; then
  failc "PREDICATE-PRESENT: scripts/test/check-cycle-layer-index.sh is absent — this suite has no logic to call"
else
  pass "PREDICATE-PRESENT: scripts/test/check-cycle-layer-index.sh is present"
fi

OUT="$(bash "$PREDICATE" --root "$PROJECT_ROOT" 2>&1)"; RC=$?
if [ "$RC" -eq 0 ]; then
  pass "INDEX-CLEAN: no path under .autoflow/issue-{N}-local/ is tracked in this repository's index"
else
  failc "INDEX-CLEAN: the predicate exited $RC over this repository; $(tr '\n' ' ' <<<"$OUT" | cut -c1-400)"
fi

# ---------------------------------------------------------------------------
# 3. The verdict is not vacuous — the predicate names the prefix it examined,
#    so "clean" is distinguishable from "looked at nothing".
# ---------------------------------------------------------------------------
if grep -qF '.autoflow/' <<<"$OUT"; then
  pass "VERDICT-NAMES-SUBJECT: the clean verdict names the prefix it examined — a not-run cannot read as a pass"
else
  failc "VERDICT-NAMES-SUBJECT: the predicate's output names no subject; $(tr '\n' ' ' <<<"$OUT" | cut -c1-300)"
fi

echo
echo "=============================================="
echo "PASS: $PASS  FAIL: $FAIL"
echo "=============================================="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
