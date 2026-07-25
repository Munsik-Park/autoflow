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
#   AC1 / AC3-migration / AC-preserve — RETIRED with the baseline fixture
#       they guarded. Their whole subject was test-16's AC5 snapshot oracle
#       (its path constant, its one-time top-level-residue migration, and its
#       seed-then-compare sequence); AC5 was retired as a cycle-scoped guard
#       whose cycle merged long ago. Disposition:
#       docs/doc-invariant-registry.md §5.
#   AC-scope (static, negative property) — check-autoflow-gate.sh is
#       byte-unchanged by this fix (ledger E2); the discovery-glob line is
#       asserted unmodified.
#
# What remains is the durable pair: the hook's discovery surface is
# single-level, so a non-state JSON at the .autoflow top level fail-closed
# blocks score-gated commands while the same file under .autoflow/fixtures/
# does not (AC2), and the hook itself is untouched (AC-scope).
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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
