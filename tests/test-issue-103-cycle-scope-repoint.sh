#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/test/check-cycle-scope-guard.sh scripts/test/suite-manifest.sh
# =============================================================================
# Test: cycle-scope guard re-point — subject binding off the filename glob
#       onto suite_enumerate + allow-list-array test, issue-number source off
#       the basename derivation onto the header's cycle-arm value
#       — Issue #103, AC-cycle-scoped-branch-inertness, AC-cycle-scope-guard-repoint
# =============================================================================
# .autoflow/issue-103-verification-design.md:
#   AC-cycle-scoped-branch-inertness — the automated carrier IS
#   check-cycle-scope-guard.sh (not the manifest lint); run it (self-test then
#   real tree) on both sides of the §2.1 re-point and require exit 0 and the
#   same subject count.
#   AC-cycle-scope-guard-repoint — --self-test on fixtures carrying headers
#   instead of issue-numbered names: match/mismatch/no-derivable-cycle-arm
#   arms, plus the subject-binding arm (a renamed-off-convention fixture with
#   an allow-list array and a cycle-arm must be IN the subject set).
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LINT="$PROJECT_ROOT/scripts/test/check-cycle-scope-guard.sh"

PASS=0; FAIL=0; TESTS=0
assert_true() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if eval "$condition"; then
    echo "  PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

echo "=== Issue #103 — check-cycle-scope-guard.sh re-point (cycle-arm subject binding) ==="

assert_true "check-cycle-scope-guard.sh exists" "[ -f '$LINT' ]"

if [ -f "$LINT" ]; then
  assert_true "check-cycle-scope-guard.sh --self-test exits 0 under the re-pointed (cycle-arm) subject binding" \
    "bash '$LINT' --self-test >/tmp/issue103-cyclescope-selftest.out 2>&1"

  REAL_OUT="$(bash "$LINT" 2>&1)"
  REAL_EXIT=$?
  assert_true "check-cycle-scope-guard.sh exits 0 on the real tree, post-re-point" "[ $REAL_EXIT -eq 0 ]"

  assert_true "AC-cycle-scoped-branch-inertness verdict-preservation: the real tree still reports exactly 3 allow-list-bearing suites after the re-point" \
    "printf '%s\n' \"$REAL_OUT\" | grep -q '3 allow-list-bearing suite'"

  # ---------------------------------------------------------------------
  # AC-cycle-scope-guard-repoint: self-test fixtures keyed on header, not
  # filename. The lint's self-test is expected to already exercise these
  # arms internally per the AC; this outer suite additionally drives the
  # subject-binding claim on a hermetic fixture root, since the rename
  # claim ("subject set is total, not filename-bound") is falsifiable only
  # outside the self-test's own fixture set.
  # ---------------------------------------------------------------------
  RENAME_DIR="$(mktemp -d)"; mkdir -p "$RENAME_DIR/tests"
  cat > "$RENAME_DIR/tests/renamed-off-convention-fixture.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# cycle-arm: #103
set -uo pipefail
HEAD_BRANCH="dev/2026-08-16-issue-103"
case "$HEAD_BRANCH" in
  dev/*-issue-103)
    allow_list=(
      "tests/fixture.sh"
    )
    for p in "${allow_list[@]}"; do :; done
    ;;
esac
SH
  bash "$LINT" --root "$RENAME_DIR" --list-subjects >/tmp/issue103-cyclescope-subjects.out 2>&1
  assert_true "AC-cycle-scope-guard-repoint subject-binding arm: a fixture whose filename is outside test-issue-* is IN the guard's subject set when it carries an allow-list array and a cycle-arm" \
    "grep -qF 'tests/renamed-off-convention-fixture.sh' /tmp/issue103-cyclescope-subjects.out"
  rm -rf "$RENAME_DIR"

  # -- Match arm: gate matches its cycle-arm -> ok --------------------------
  MATCH_DIR="$(mktemp -d)"; mkdir -p "$MATCH_DIR/tests"
  cat > "$MATCH_DIR/tests/test-fixture-103-cyclearm-match.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# cycle-arm: #103
set -uo pipefail
HEAD_BRANCH="dev/2026-08-16-issue-103"
case "$HEAD_BRANCH" in
  dev/*-issue-103)
    allow_list=(
      "tests/fixture.sh"
    )
    for p in "${allow_list[@]}"; do :; done
    ;;
esac
SH
  bash "$LINT" --root "$MATCH_DIR" >/tmp/issue103-cyclescope-match.out 2>&1
  assert_true "AC-cycle-scope-guard-repoint match arm: a fixture whose gate matches its cycle-arm is conforming" \
    "! grep -qF 'test-fixture-103-cyclearm-match.sh' /tmp/issue103-cyclescope-match.out"
  rm -rf "$MATCH_DIR"

  # -- Mismatch arm: gate names a different issue than cycle-arm -> violation
  MISMATCH_DIR="$(mktemp -d)"; mkdir -p "$MISMATCH_DIR/tests"
  cat > "$MISMATCH_DIR/tests/test-fixture-103-cyclearm-mismatch.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
# cycle-arm: #999
set -uo pipefail
HEAD_BRANCH="dev/2026-08-16-issue-103"
case "$HEAD_BRANCH" in
  dev/*-issue-103)
    allow_list=(
      "tests/fixture.sh"
    )
    for p in "${allow_list[@]}"; do :; done
    ;;
esac
SH
  bash "$LINT" --root "$MISMATCH_DIR" >/tmp/issue103-cyclescope-mismatch.out 2>&1
  assert_true "AC-cycle-scope-guard-repoint mismatch arm: a fixture whose gate names a different issue than its cycle-arm is a violation" \
    "grep -qF 'test-fixture-103-cyclearm-mismatch.sh' /tmp/issue103-cyclescope-mismatch.out"
  rm -rf "$MISMATCH_DIR"

  # -- No-derivable-cycle-arm arm: array-bearing, no cycle-arm -> this
  #    lint's own named violation, not a silent skip.
  NOARM_DIR="$(mktemp -d)"; mkdir -p "$NOARM_DIR/tests"
  cat > "$NOARM_DIR/tests/test-fixture-103-noarm.sh" <<'SH'
#!/usr/bin/env bash
# ci-subject: tests/fixture.sh
# lane: standing
set -uo pipefail
HEAD_BRANCH="dev/2026-08-16-issue-103"
allow_list=(
  "tests/fixture.sh"
)
for p in "${allow_list[@]}"; do :; done
SH
  bash "$LINT" --root "$NOARM_DIR" >/tmp/issue103-cyclescope-noarm.out 2>&1
  assert_true "AC-cycle-scope-guard-repoint no-derivable-cycle-arm arm: an array-bearing fixture with no derivable cycle-arm is THIS lint's own named violation" \
    "grep -qF 'test-fixture-103-noarm.sh' /tmp/issue103-cyclescope-noarm.out && grep -qi 'cycle-arm' /tmp/issue103-cyclescope-noarm.out"
  rm -rf "$NOARM_DIR"

  # -- Migration invariant: each of the three real subjects is verdict-
  #    preserving under the new binding (their cycle-arm equals their own
  #    filename issue number, so re-pointing changes no real-tree verdict).
  for f in tests/test-issue-67-deliberation-record.sh tests/test-issue-69-verification-depth.sh tests/test-issue-71-digest-removal.sh; do
    num="$(printf '%s' "$f" | sed -n 's/^tests\/test-issue-\([0-9][0-9]*\)-.*$/\1/p')"
    assert_true "migration invariant: $f's cycle-arm (#$num) equals its own filename issue number, so the re-point is verdict-preserving" \
      "grep -qE \"^# cycle-arm: #$num\\\$\" '$PROJECT_ROOT/$f'"
  done
fi

echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
