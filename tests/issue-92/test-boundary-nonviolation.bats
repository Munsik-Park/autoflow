#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# tests/issue-92/test-boundary-nonviolation.bats — AC11, AC12 boundary scan.
#
# T11-1a-i..v: content scan on new files (F1, F2, F3, F7) for forbidden
#   command patterns. Tests require ALL target files to exist (so they fail
#   RED until GREEN), then verify no forbidden pattern occurs.
# T11-1b: diff scan — no modifications under services/ in this
#   branch. Always evaluable.
# T12-1a: the gate-label removal deny covers both blocked-by-* labels
#   (operator-owned blocked-by-subrepo extension). State assertion only — the
#   diff-shaped halves of T12-1a/T12-1b were retired by issue #75.

REPO_ROOT="${BATS_TEST_DIRNAME}/../.."

# Issue #795 (ADR-0015 D3): .github/workflows/handoff-sequence.yml was
# physically removed, so it is no longer in the boundary-scan file set.
NEW_FILES=(
  ".github/pull_request_template.md"
  "scripts/handoff/create-host-pr.sh"
  "docs/external-review-sequencing.md"
)

# Helper: require all NEW_FILES to exist; bail with a clear failure otherwise.
require_all_new_files() {
  for f in "${NEW_FILES[@]}"; do
    if [ ! -f "$REPO_ROOT/$f" ]; then
      echo "expected new file missing: $f" >&2
      return 1
    fi
  done
}

@test "T11-1a-i: new files do not contain 'gh pr merge'" {
  require_all_new_files
  for f in "${NEW_FILES[@]}"; do
    p="$REPO_ROOT/$f"
    if grep -qE 'gh[[:space:]]+pr[[:space:]]+merge\b' "$p"; then
      echo "forbidden pattern 'gh pr merge' found in $f" >&2
      return 1
    fi
  done
}

@test "T11-1a-ii: new files do not contain 'gh pr ready'" {
  require_all_new_files
  for f in "${NEW_FILES[@]}"; do
    p="$REPO_ROOT/$f"
    if grep -qE 'gh[[:space:]]+pr[[:space:]]+ready\b' "$p"; then
      echo "forbidden pattern 'gh pr ready' found in $f" >&2
      return 1
    fi
  done
}

@test "T11-1a-iii: new files do not push to default branch" {
  require_all_new_files
  for f in "${NEW_FILES[@]}"; do
    p="$REPO_ROOT/$f"
    if grep -qE 'git[[:space:]]+push[[:space:]]+(\S+[[:space:]]+)?origin[[:space:]]+(main|master)\b' "$p"; then
      echo "forbidden pattern 'git push origin main/master' found in $f" >&2
      return 1
    fi
  done
}

@test "T11-1a-iv: new files do not auto-update submodule pointer" {
  require_all_new_files
  for f in "${NEW_FILES[@]}"; do
    p="$REPO_ROOT/$f"
    if grep -qE 'git[[:space:]]+submodule[[:space:]]+update[[:space:]]+--remote\b' "$p"; then
      echo "forbidden pattern 'git submodule update --remote' found in $f" >&2
      return 1
    fi
  done
}

# T11-1a-v removed with issue #795: it scanned the deleted
# .github/workflows/handoff-sequence.yml for a 'pull_request.merge' trigger;
# the workflow no longer exists.

@test "T11-1b: host tracks no blobs under the services submodule" {
  cd "$REPO_ROOT"
  # Gate on production-file presence so the test is RED until GREEN, then
  # continues to enforce the boundary invariant through VERIFY / VALIDATE.
  require_all_new_files
  # nested: the host tracks `services` as a gitlink (the llmroute submodule);
  # its contents are llmroute's tree, never the host's. A diff-based check would
  # mis-flag the one-time `services/librechat` -> `services` gitlink restructure
  # as a sub-repo file change, so assert the invariant on the HEAD tree state:
  # no blob may be tracked under services/ (a gitlink entry is type `commit`).
  tracked_blobs="$(git ls-tree -r HEAD -- services 2>/dev/null | awk '$2 == "blob" {print $NF}')"
  if [ -n "$tracked_blobs" ]; then
    echo "forbidden: host tracks blobs under services/:" >&2
    echo "$tracked_blobs" >&2
    return 1
  fi
}

# T12-1a retains only its positive STATE half. The diff-shaped half compared
# against a fixed origin/main base, so its diff was unconditionally empty on
# any branch that does not touch the hook — retired by issue #75 along with
# T12-1b, which had the same shape over CLAUDE.md.
@test "T12-1a: the gate-label deny covers both blocked-by-* labels" {
  cd "$REPO_ROOT"
  require_all_new_files
  grep -qF 'blocked-by-(review|subrepo)' "$REPO_ROOT/.claude/hooks/check-autoflow-gate.sh"
}
