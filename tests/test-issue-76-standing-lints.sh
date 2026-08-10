#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: standing lints — manifest regen-clean (AC-e/AC-g), tests-tree hygiene
#       (manifest-closure-residual (ii)) — Issue #76
# =============================================================================
# .autoflow/issue-76-verification-design.md:
#   AC-e — manifest closure and hash pins consistent after the doc edits:
#     regenerate with setup/gen-manifest-hashes.sh, re-run hash-freshness /
#     source-closure suites.
#   AC-g — the 955 AC4-CLOSURE retirement leaves a live carrier
#     (scripts/test/check-manifest-regen-clean.sh) for each promoted half,
#     driven to a real FAIL on each of its two independent lanes:
#       Drive 1 — bundle registration: an unregistered file under
#         setup/thin-root-layer/** in a scratch worktree -> FAIL, attributed
#         to the bundle-registration leg.
#       Drive 2 — fixed point: a document linked into the CLAUDE.md /
#         docs/INDEX.md closure without regeneration in a scratch worktree
#         -> FAIL, attributed to the fixed-point leg.
#     Specificity (not blocked on scores): a green default run on an
#     unmodified tree.
#   manifest-closure-residual (ii) — the retired 75 NUL-byte-absence check
#     promoted to scripts/test/check-tests-tree-hygiene.sh, with a planted-
#     NUL --self-test fixture (a working tree has no NUL byte, so the live
#     tree alone cannot distinguish a working detector from a broken one).
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REGEN_LINT="$PROJECT_ROOT/scripts/test/check-manifest-regen-clean.sh"
HYGIENE_LINT="$PROJECT_ROOT/scripts/test/check-tests-tree-hygiene.sh"

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

echo "=== Issue #76 — standing lints: regen-clean, hygiene (AC-e/AC-g, manifest-closure-residual ii) ==="

# ---------------------------------------------------------------------------
# AC-e/AC-g — manifest regen-clean lint
# ---------------------------------------------------------------------------
assert_true "AC-g: scripts/test/check-manifest-regen-clean.sh exists" "[ -f '$REGEN_LINT' ]"

assert_true "AC-g specificity: check-manifest-regen-clean.sh exits 0 on the current unmodified tree (fixed point)" \
  "[ -f '$REGEN_LINT' ] && bash '$REGEN_LINT' >/tmp/issue76-regen-clean.out 2>&1"

if [ -f "$REGEN_LINT" ]; then
  SCRATCH1="$(mktemp -d)"
  git -C "$PROJECT_ROOT" worktree add -q "$SCRATCH1" HEAD >/dev/null 2>&1
  mkdir -p "$SCRATCH1/setup/thin-root-layer"
  echo "unregistered probe" > "$SCRATCH1/setup/thin-root-layer/issue-76-unregistered-probe.txt"
  bash "$REGEN_LINT" --root "$SCRATCH1" >/tmp/issue76-regen-drive1.out 2>&1 \
    || bash -c "cd '$SCRATCH1' && bash '$REGEN_LINT'" >/tmp/issue76-regen-drive1.out 2>&1
  drive1_exit=$?
  assert_true "AC-g Drive 1 (bundle-registration lane): an unregistered setup/thin-root-layer/** file drives the lint to FAIL, attributed to its own lane" \
    "[ $drive1_exit -ne 0 ] && grep -qi 'bundle' /tmp/issue76-regen-drive1.out"
  git -C "$PROJECT_ROOT" worktree remove -f "$SCRATCH1" >/dev/null 2>&1 || rm -rf "$SCRATCH1"

  SCRATCH2="$(mktemp -d)"
  git -C "$PROJECT_ROOT" worktree add -q "$SCRATCH2" HEAD >/dev/null 2>&1
  {
    echo ""
    echo "See [issue-76 probe doc](docs/issue-76-regen-clean-probe.md)"
  } >> "$SCRATCH2/CLAUDE.md"
  echo "# probe" > "$SCRATCH2/docs/issue-76-regen-clean-probe.md"
  bash -c "cd '$SCRATCH2' && bash '$REGEN_LINT'" >/tmp/issue76-regen-drive2.out 2>&1
  drive2_exit=$?
  assert_true "AC-g Drive 2 (fixed-point lane): a document linked into the CLAUDE.md/docs/INDEX.md closure without regeneration drives the lint to FAIL, attributed to its own lane" \
    "[ $drive2_exit -ne 0 ] && grep -qi 'fixed.point\|fixed point\|closure' /tmp/issue76-regen-drive2.out"
  git -C "$PROJECT_ROOT" worktree remove -f "$SCRATCH2" >/dev/null 2>&1 || rm -rf "$SCRATCH2"
fi

# ---------------------------------------------------------------------------
# manifest-closure-residual (ii) — tests-tree hygiene lint
# ---------------------------------------------------------------------------
assert_true "manifest-closure-residual(ii): scripts/test/check-tests-tree-hygiene.sh exists" "[ -f '$HYGIENE_LINT' ]"

assert_true "manifest-closure-residual(ii): check-tests-tree-hygiene.sh exits 0 over the real tests/** tree (no NUL bytes)" \
  "[ -f '$HYGIENE_LINT' ] && bash '$HYGIENE_LINT' >/tmp/issue76-hygiene.out 2>&1"

if [ -f "$HYGIENE_LINT" ]; then
  SCRATCH3="$(mktemp -d)"
  mkdir -p "$SCRATCH3/tests"
  printf 'before\000after\n' > "$SCRATCH3/tests/issue-76-planted-nul-fixture.sh"
  bash "$HYGIENE_LINT" --root "$SCRATCH3" >/tmp/issue76-hygiene-fixture.out 2>&1
  fixture_exit=$?
  assert_true "manifest-closure-residual(ii) --self-test: a planted-NUL fixture file is detected and drives the lint to non-zero exit" \
    "[ $fixture_exit -ne 0 ] && grep -qF 'issue-76-planted-nul-fixture.sh' /tmp/issue76-hygiene-fixture.out"
  rm -rf "$SCRATCH3"
fi

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
