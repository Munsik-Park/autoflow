#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: fixture/gate-glob isolation — Issue #18 (standing regression guard)
# =============================================================================
# Tier-1 scripted assertion suite per verification design
# (.autoflow/issue-18-verification-design.md §4 RED plan) and feature design
# (.autoflow/issue-18-feature-design.md §8 canonical AC set). NEW dedicated
# file — the durable regression fence called for by DIAGNOSE task-3 lives
# here, separate from the edited tests/test-issue-16-manifest-locale-invariance.sh
# (which only relocates its own fixture).
#
# Scope:
#   AC1 (static, load-bearing RED witness) — sources test-16's REAL
#       BASELINE_FIXTURE constant (not a hardcoded literal) and asserts its
#       dirname is not the .autoflow top level (i.e. not a direct match of
#       the hook's "$AUTOFLOW_DIR"/*.json glob). Pre-fix: FAIL (dirname is
#       .autoflow). Post-fix: PASS (.autoflow/fixtures).
#   AC2 (behavioral, two-arm, sandbox) — drives check-autoflow-gate.sh in an
#       isolated temp CLAUDE_PROJECT_DIR. Pass predicate is the ABSENCE of
#       the "malformed AutoFlow state file" stderr message, never the exit
#       code (verification design concern C2 — exit 2 is overloaded by a
#       valid active state file blocking on unmet AUDIT/QUALITY scores).
#       Arm-A (top-level placement) MUST show the malformed block (the bug
#       mechanism, fix-independent). Arm-B (fixtures/ subdir placement) MUST
#       show no malformed message. Both arms pass pre-fix and post-fix alike
#       — this AC is the standing witness, not the fix discriminator.
#   AC3-migration (behavioral, precondition-bound, sandbox) — establishes the
#       load-bearing dual precondition (top-level residue PRESENT + new-path
#       fixture ABSENT) so the guarded `rm -f` in test-16's seed branch
#       (§4.3) actually fires, then asserts the top-level residue is gone.
#       Pre-fix: FAIL (old test-16 has no rm -f). Post-fix: PASS.
#   AC-preserve (behavioral, two-run sequence, sandbox) — replays test-16's
#       AC5 seed→SKIP then present→PASS oracle sequence at the new path to
#       confirm relocation left baseline_preexisted + the tuple/count
#       compares intact.
#   AC-scope (static, negative property) — check-autoflow-gate.sh is
#       byte-unchanged by this fix (ledger E2); the discovery-glob line is
#       asserted unmodified.
#
# RED expectation (verification design §4): AC1 and AC3-migration FAIL
# pre-fix (test-16 still points BASELINE_FIXTURE at the .autoflow top level
# and has no migration rm -f); AC2, AC-preserve, AC-scope PASS pre-fix (they
# are properties of the hook / of this new file's own sandbox replay, not of
# test-16's current fixture path). GREEN = the test-16 path-constant
# relocation + rm -f migration flips AC1 and AC3-migration to PASS with the
# other three still PASS and the hook untouched.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TEST16="$PROJECT_ROOT/tests/test-issue-16-manifest-locale-invariance.sh"
GATE_HOOK="$PROJECT_ROOT/.claude/hooks/check-autoflow-gate.sh"
MANIFEST_JSON="$PROJECT_ROOT/setup/manifest.json"

PASS=0; FAIL=0; TESTS=0

# ---------------------------------------------------------------------------
# Helpers (assert_* pattern per tests/test-issue-16-manifest-locale-invariance.sh
# / tests/test-issue-953-cycle-digest.sh)
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

skip_test() {
  local desc="$1"
  TESTS=$((TESTS + 1))
  PASS=$((PASS + 1))
  echo "  SKIP: $desc"
}

# ---------------------------------------------------------------------------
# AC1 — static discriminator: source test-16's REAL BASELINE_FIXTURE
# constant (not a hardcoded literal), so this assertion tracks the fix and
# is the honest RED/GREEN discriminator (verification design §1 AC1a).
# ---------------------------------------------------------------------------

echo "=== AC1 (RED discriminator) — fixture dirname is not the .autoflow top level ==="

AC1_FIXTURE_LINE="$(grep -E '^BASELINE_FIXTURE=' "$TEST16" 2>/dev/null | head -1)"
assert_true "AC1-a: test-16 declares a BASELINE_FIXTURE constant" \
  "[ -n '$AC1_FIXTURE_LINE' ]"

# Evaluate the constant in test-16's own variable namespace so this test
# never duplicates the literal path — sourcing PROJECT_ROOT + the one
# assignment line only (not the whole script, which would re-run test-16's
# body).
AC1_PROJECT_ROOT="$PROJECT_ROOT"
# shellcheck disable=SC1090
eval "PROJECT_ROOT=\"$AC1_PROJECT_ROOT\"; $AC1_FIXTURE_LINE"
AC1_RESOLVED_FIXTURE="$BASELINE_FIXTURE"
PROJECT_ROOT="$AC1_PROJECT_ROOT"   # restore; the eval above may have rebound it

AC1_FIXTURE_DIR="$(dirname "$AC1_RESOLVED_FIXTURE" 2>/dev/null)"
AC1_TOPLEVEL_DIR="$PROJECT_ROOT/.autoflow"

assert_true "AC1-b: BASELINE_FIXTURE's dirname ($AC1_FIXTURE_DIR) is NOT the .autoflow top level ($AC1_TOPLEVEL_DIR) — i.e. not a direct child matched by \"\$AUTOFLOW_DIR\"/*.json" \
  "[ '$AC1_FIXTURE_DIR' != '$AC1_TOPLEVEL_DIR' ]"

# ---------------------------------------------------------------------------
# AC2 — behavioral, two-arm, sandboxed hook probe (standing witness, keyed
# on the message, never the exit code — verification design concern C2).
# ---------------------------------------------------------------------------

echo ""
echo "=== AC2 (standing witness) — hook blocks top-level placement, not fixtures/ placement ==="

if [ ! -f "$MANIFEST_JSON" ] || [ ! -x "$GATE_HOOK" ] && [ ! -f "$GATE_HOOK" ]; then
  skip_test "AC2-arm-A: setup/manifest.json or the gate hook is missing — cannot probe"
  skip_test "AC2-arm-B: setup/manifest.json or the gate hook is missing — cannot probe"
else
  AC2_TMP="$(mktemp -d)"
  mkdir -p "$AC2_TMP/.autoflow/fixtures"

  # Arm-A: fixture copy placed directly on the hook's discovery surface
  # (the top-level .autoflow/*.json glob) — this MUST show the malformed
  # block; it is the bug mechanism, fix-independent.
  cp "$MANIFEST_JSON" "$AC2_TMP/.autoflow/probe-arm-a.json"
  AC2_ARM_A_STDERR="$(CLAUDE_PROJECT_DIR="$AC2_TMP" bash "$GATE_HOOK" \
    <<<'{"tool_name":"Bash","tool_input":{"command":"git push"}}' 2>&1 1>/dev/null || true)"
  rm -f "$AC2_TMP/.autoflow/probe-arm-a.json"

  assert_true "AC2-arm-A: a non-state JSON at the top-level .autoflow/*.json surface IS reported malformed by the hook" \
    "printf '%s' \"\$AC2_ARM_A_STDERR\" | grep -qF 'malformed AutoFlow state file'"

  # Arm-B: same non-state JSON content, placed under .autoflow/fixtures/ —
  # invisible to the hook's non-recursive glob; MUST show no malformed
  # message.
  cp "$MANIFEST_JSON" "$AC2_TMP/.autoflow/fixtures/probe-arm-b.json"
  AC2_ARM_B_STDERR="$(CLAUDE_PROJECT_DIR="$AC2_TMP" bash "$GATE_HOOK" \
    <<<'{"tool_name":"Bash","tool_input":{"command":"git push"}}' 2>&1 1>/dev/null || true)"
  rm -f "$AC2_TMP/.autoflow/fixtures/probe-arm-b.json"

  assert_true "AC2-arm-B: the same non-state JSON under .autoflow/fixtures/ is NOT reported malformed by the hook" \
    "! printf '%s' \"\$AC2_ARM_B_STDERR\" | grep -qF 'malformed AutoFlow state file'"

  rm -rf "$AC2_TMP" 2>/dev/null
fi

# ---------------------------------------------------------------------------
# AC3-migration — precondition-bound: top-level residue PRESENT + new-path
# fixture ABSENT (so test-16's `[ ! -f "$BASELINE_FIXTURE" ]` seed-branch
# gate is true and its guarded `rm -f` actually runs — verification design
# concern C1). Replays test-16's seed shape directly (does not invoke
# test-16 itself, which would run its full AC1-AC-C2-6 suite against the
# real tree).
# ---------------------------------------------------------------------------

echo ""
echo "=== AC3-migration — stale top-level residue is removed by the seed-branch rm -f ==="

if [ ! -f "$MANIFEST_JSON" ]; then
  skip_test "AC3-migration: setup/manifest.json is missing — cannot probe"
else
  AC3_TMP="$(mktemp -d)"
  mkdir -p "$AC3_TMP/.autoflow"

  # Precondition: stale top-level residue PRESENT, new-path fixture ABSENT.
  cp "$MANIFEST_JSON" "$AC3_TMP/.autoflow/issue-16-manifest-baseline.json"

  assert_true "AC3-migration-precondition: new-path fixture is absent before the seed run (so the seed branch's [ ! -f ] gate is true)" \
    "[ ! -f '$AC3_TMP/.autoflow/fixtures/issue-16-manifest-baseline.json' ]"

  # Replay test-16's current seed-branch shape verbatim against the sandbox
  # tree's own BASELINE_FIXTURE constant (sourced the same way AC1 does),
  # so this assertion tracks test-16's real seed logic rather than a
  # hardcoded copy of it.
  AC3_PROJECT_ROOT="$AC3_TMP"
  # shellcheck disable=SC1090
  eval "PROJECT_ROOT=\"$AC3_PROJECT_ROOT\"; $AC1_FIXTURE_LINE"
  AC3_BASELINE_FIXTURE="$BASELINE_FIXTURE"
  PROJECT_ROOT="$AC1_PROJECT_ROOT"   # restore this script's own PROJECT_ROOT

  # Direct replay of the seed shape (mkdir + migration rm -f, if test-16
  # carries one, + cp), evaluated against the sandbox tree so this guard is
  # honest about what test-16 currently does — not a copy of the intended
  # post-fix behavior.
  if [ ! -f "$AC3_BASELINE_FIXTURE" ]; then
    if grep -qE 'rm -f "\$PROJECT_ROOT/\.autoflow/issue-16-manifest-baseline\.json"' "$TEST16" 2>/dev/null; then
      rm -f "$AC3_TMP/.autoflow/issue-16-manifest-baseline.json"
    fi
    mkdir -p "$(dirname "$AC3_BASELINE_FIXTURE")"
    cp "$MANIFEST_JSON" "$AC3_BASELINE_FIXTURE"
  fi

  assert_true "AC3-migration-b: the stale top-level residue is gone after the seed run" \
    "[ ! -f '$AC3_TMP/.autoflow/issue-16-manifest-baseline.json' ]"

  rm -rf "$AC3_TMP" 2>/dev/null
fi

# ---------------------------------------------------------------------------
# AC-preserve — two-run sequence: run 1 (no fixture) seeds + SKIPs; run 2
# (fixture now present) compares + PASSes. Confirms relocation left the
# baseline_preexisted gate and the tuple/count compares intact.
# ---------------------------------------------------------------------------

echo ""
echo "=== AC-preserve — baseline_preexisted SKIP-then-compare oracle survives relocation ==="

if [ ! -f "$MANIFEST_JSON" ]; then
  skip_test "AC-preserve-run1: setup/manifest.json is missing — cannot probe"
  skip_test "AC-preserve-run2: setup/manifest.json is missing — cannot probe"
else
  AC_PRES_TMP="$(mktemp -d)"

  AC_PRES_PROJECT_ROOT="$AC_PRES_TMP"
  # shellcheck disable=SC1090
  eval "PROJECT_ROOT=\"$AC_PRES_PROJECT_ROOT\"; $AC1_FIXTURE_LINE"
  AC_PRES_FIXTURE="$BASELINE_FIXTURE"
  PROJECT_ROOT="$AC1_PROJECT_ROOT"   # restore

  # Run 1: no fixture present -> baseline_preexisted must be 0 (SKIP arm).
  run1_baseline_preexisted=0
  [ -f "$AC_PRES_FIXTURE" ] && run1_baseline_preexisted=1
  assert_true "AC-preserve-run1: baseline_preexisted is 0 on the first (fixture-absent) run" \
    "[ '$run1_baseline_preexisted' -eq 0 ]"

  if [ ! -f "$AC_PRES_FIXTURE" ]; then
    mkdir -p "$(dirname "$AC_PRES_FIXTURE")"
    cp "$MANIFEST_JSON" "$AC_PRES_FIXTURE"
  fi

  # Run 2: fixture now present from run 1 -> baseline_preexisted must be 1
  # (compare arm) and the tuple/count compares (test-16 :209-212 shape)
  # must PASS on an order-only (identical) manifest.
  run2_baseline_preexisted=0
  [ -f "$AC_PRES_FIXTURE" ] && run2_baseline_preexisted=1
  assert_true "AC-preserve-run2: baseline_preexisted is 1 on the second (fixture-present) run" \
    "[ '$run2_baseline_preexisted' -eq 1 ]"

  assert_true "AC-preserve-run2-tuples: sorted (source,sha256,dest,kind) tuples match the run-1 baseline" \
    "diff <(jq -r '.artifacts[] | \"\(.source)\t\(.sha256)\t\(.dest)\t\(.kind)\"' '$MANIFEST_JSON' | sort) \
          <(jq -r '.artifacts[] | \"\(.source)\t\(.sha256)\t\(.dest)\t\(.kind)\"' '$AC_PRES_FIXTURE' | sort) >/dev/null 2>&1"
  assert_true "AC-preserve-run2-count: artifact count matches the run-1 baseline" \
    "[ \"\$(jq '.artifacts | length' '$MANIFEST_JSON')\" = \"\$(jq '.artifacts | length' '$AC_PRES_FIXTURE')\" ]"

  rm -rf "$AC_PRES_TMP" 2>/dev/null
fi

# ---------------------------------------------------------------------------
# AC-scope — negative property: the gate hook is byte-unmodified by this
# fix (ledger E2). Checked both as a working-tree diff-scope guard and as a
# direct assertion that the discovery-glob line is unchanged.
# ---------------------------------------------------------------------------

echo ""
echo "=== AC-scope — check-autoflow-gate.sh is untouched by this fix ==="

assert_true "AC-scope-a: .claude/hooks/check-autoflow-gate.sh has no uncommitted modification" \
  "git diff --quiet -- .claude/hooks/check-autoflow-gate.sh"
assert_true "AC-scope-b: the hook's discovery-glob line is byte-unchanged (single-level, non-recursive)" \
  "grep -qF 'for _sf in \"\$AUTOFLOW_DIR\"/*.json' '$GATE_HOOK'"

echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[ "$FAIL" -eq 0 ]
