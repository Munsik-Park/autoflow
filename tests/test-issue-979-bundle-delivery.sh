#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: reviewer-backend bundle delivery + install config scaffold (packaging /
#       manifest)
# =============================================================================
# The manifest ships the artifacts HANDOFF step 6 executes on a target — two
# `copy` scripts (scripts/review/codex-review-pr.sh,
# scripts/preflight/check-review-backend.sh), one `copy` for .codex/review.md,
# two `scaffold` rows (AGENTS.md, .claude/autoflow.local.json) — and a fresh
# mktemp install materializes all five. The scaffold ships its codex default and
# is never overwritten by a re-install.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INIT_SH="$PROJECT_ROOT/setup/init.sh"
MANIFEST="$PROJECT_ROOT/setup/manifest.json"

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

echo "=============================================="
echo "reviewer-backend bundle delivery (AC-3a / AC-4)"
echo "=============================================="

echo "=== manifest rows (AC-4) ==="

assert_true "AC-4: manifest ships scripts/review/codex-review-pr.sh as a copy artifact" \
  "jq -e '.artifacts[] | select(.source == \"scripts/review/codex-review-pr.sh\" and .kind == \"copy\")' '$MANIFEST' >/dev/null 2>&1"
assert_true "AC-4: manifest ships scripts/preflight/check-review-backend.sh as a copy artifact" \
  "jq -e '.artifacts[] | select(.source == \"scripts/preflight/check-review-backend.sh\" and .kind == \"copy\")' '$MANIFEST' >/dev/null 2>&1"
assert_true "AC-4: manifest ships .codex/review.md as a copy artifact" \
  "jq -e '.artifacts[] | select(.source == \".codex/review.md\" and .kind == \"copy\")' '$MANIFEST' >/dev/null 2>&1"
assert_true "AC-4: manifest ships AGENTS.md as a scaffold artifact" \
  "jq -e '.artifacts[] | select(.source == \"AGENTS.md\" and .kind == \"scaffold\")' '$MANIFEST' >/dev/null 2>&1"
assert_true "AC-3a/AC-4: manifest ships .claude/autoflow.local.json as a scaffold artifact, sourced from the neutral .example (#225)" \
  "jq -e '.artifacts[] | select(.source == \".claude/autoflow.local.json.example\" and .dest == \".claude/autoflow.local.json\" and .kind == \"scaffold\")' '$MANIFEST' >/dev/null 2>&1"

echo ""
echo "=== fresh mktemp install materializes all five artifacts + never-overwrite scaffold arm ==="

TARGET="$(mktemp -d)"
# The target already declares its own test command (ADR-0024 D3 discovery
# route 2); the stamp must not inject a higher-priority one (#225).
printf '## Development Commands\n- **Test**: `npm test`\n' > "$TARGET/CLAUDE.md"
( bash "$INIT_SH" --target "$TARGET" </dev/null >/tmp/init-979-log.log 2>&1 )
INIT_EXIT=$?

assert_true "install: init.sh --target exits 0" "[ '$INIT_EXIT' -eq 0 ]"
assert_true "AC-4: installed target has scripts/review/codex-review-pr.sh" \
  "[ -f '$TARGET/scripts/review/codex-review-pr.sh' ]"
assert_true "AC-4: installed target has scripts/preflight/check-review-backend.sh" \
  "[ -f '$TARGET/scripts/preflight/check-review-backend.sh' ]"
assert_true "AC-4: installed target has .codex/review.md" \
  "[ -f '$TARGET/.codex/review.md' ]"
assert_true "AC-4: installed target has AGENTS.md (scaffold)" \
  "[ -f '$TARGET/AGENTS.md' ]"
assert_true "AC-3a: installed target has .claude/autoflow.local.json (scaffold) shipping the codex default" \
  "[ -f '$TARGET/.claude/autoflow.local.json' ] && jq -e '.review.backend == \"codex\"' '$TARGET/.claude/autoflow.local.json' >/dev/null 2>&1"
assert_true "#229 / #238 (ADR-0024 D3/S4): the stamped scaffold carries the tests declaration site with no suite-plane opt-in and no test-command key, as the shipped resolver reads it — AutoFlow asks the target for no test command" \
  "( . '$PROJECT_ROOT/scripts/test/suite-manifest.sh'; suite_plane_declared '$TARGET' && ! suite_plane_opted_in '$TARGET' ) && jq -e '.tests | has(\"command\") | not' '$TARGET/.claude/autoflow.local.json' >/dev/null 2>&1"

# Never-overwrite arm (C3 RESOLVED — mirror CLAUDE.local.md/AC1j): a target
# operator's explicit backend=claude selection survives a second install.
if [ -f "$TARGET/.claude/autoflow.local.json" ]; then
  cat > "$TARGET/.claude/autoflow.local.json" <<'EOF'
{ "review": { "backend": "claude" } }
EOF
  ( bash "$INIT_SH" --target "$TARGET" </dev/null >/tmp/init-979-reinstall.log 2>&1 )
  assert_true "AC-3a (no silent downgrade): a re-install does NOT overwrite an operator's explicit backend=claude selection" \
    "jq -e '.review.backend == \"claude\"' '$TARGET/.claude/autoflow.local.json' >/dev/null 2>&1"
else
  assert_true "AC-3a (no silent downgrade): scaffold present to test never-overwrite arm" "false"
fi
rm -rf "$TARGET" /tmp/init-979-log.log /tmp/init-979-reinstall.log 2>/dev/null

echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
