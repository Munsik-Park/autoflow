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
# T12-1a: any .claude/hooks/check-autoflow-gate.sh change vs the merge-base is
#   confined to the gate-label removal deny (operator-owned blocked-by-subrepo).
# T12-1b: CLAUDE.md "Hook gates" sentinel lines unchanged vs the merge-base.

REPO_ROOT="${BATS_TEST_DIRNAME}/../.."
BASE_REF="origin/main"

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

# T12-1 is fundamentally a negative property — by definition it must hold
# *throughout* this dev branch. To make it a RED-able phase signal, gate it on
# the presence of the GREEN-phase production files: until GREEN produces the
# new files, T12-1 reports RED as "implementation not yet started"; after
# GREEN, T12-1 enforces that any hook change is confined to the gate-label deny
# (the operator-owned blocked-by-subrepo extension) and touches nothing else.
@test "T12-1a: hook change vs origin/main is confined to the gate-label deny" {
  cd "$REPO_ROOT"
  require_all_new_files
  base="$(git merge-base HEAD "$BASE_REF" 2>/dev/null || git rev-parse "$BASE_REF" 2>/dev/null || true)"
  if [ -z "$base" ]; then
    skip "no merge-base with $BASE_REF available"
  fi
  # Making blocked-by-subrepo removal operator-owned requires extending the
  # existing gate-label removal deny (blocked-by-review → blocked-by-(review|
  # subrepo)). That is the ONLY hook change this branch may carry: every changed
  # line must belong to the gate-label deny (a blocked-by-* label or the deny's
  # own comment/message vocabulary). Any other hook edit is a boundary violation.
  changed="$(git diff "$base"..HEAD -- .claude/hooks/check-autoflow-gate.sh 2>/dev/null \
    | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' || true)"
  offending="$(printf '%s\n' "$changed" \
    | grep -vE 'blocked-by-|gate label|Codex review|operator|self-open|codex exec|does not intercept|AutoFlow owns|review gate|N sub-repos|auto-removes' \
    || true)"
  if [ -n "$offending" ]; then
    echo "hook modified outside the gate-label deny — boundary violation:" >&2
    printf '%s\n' "$offending" >&2
    return 1
  fi
  # Positively confirm the intended extension landed (deny covers both labels).
  grep -qE 'blocked-by-\(review\|subrepo\)' "$REPO_ROOT/.claude/hooks/check-autoflow-gate.sh"
}

@test "T12-1b: CLAUDE.md 'Hook gates' bullet list block is structurally unchanged" {
  cd "$REPO_ROOT"
  require_all_new_files
  base="$(git merge-base HEAD "$BASE_REF" 2>/dev/null || git rev-parse "$BASE_REF" 2>/dev/null || true)"
  if [ -z "$base" ]; then
    skip "no merge-base with $BASE_REF available"
  fi
  extract_hook_gates() {
    awk '
      /^\*\*Hook gates\*\*/ { in_section = 1; print; next }
      in_section && /^\*\*[A-Z]/ && !/^\*\*Hook gates\*\*/ { in_section = 0 }
      in_section && /^## / { in_section = 0 }
      in_section { print }
    '
  }
  before="$(git show "$base":CLAUDE.md 2>/dev/null | extract_hook_gates || true)"
  after="$(cat "$REPO_ROOT/CLAUDE.md" | extract_hook_gates || true)"
  if [ "$before" != "$after" ]; then
    echo "CLAUDE.md Hook gates block changed:" >&2
    diff <(echo "$before") <(echo "$after") >&2 || true
    return 1
  fi
}
