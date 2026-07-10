#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: reviewer-backend bundle delivery + install config scaffold — Issue #979
# =============================================================================
# Scope (.autoflow/issue-979-verification-design.md §1 AC-3/AC-4, feature
# design D1/rows 1-10): the manifest ships five new artifacts (two `copy` —
# scripts/review/codex-review-pr.sh, scripts/preflight/check-review-backend.sh
# — one `copy` for .codex/review.md, two `scaffold` — AGENTS.md,
# .claude/autoflow.local.json), and a fresh mktemp install materializes all
# five so an installed target can actually execute HANDOFF step 6.
#
# AC-3a's realigned oracle (verification design §1, C3 RESOLVED): the scaffold
# ALWAYS ships its codex default (never-overwrite arm) — "unset" is not the
# fail-closed trigger; a codex-absent target fails closed at the codex-
# presence probe (AC-2), not on an unset field.
#
# RED expectation (pre-implementation, this commit): ALL assertions FAIL — the
# manifest carries none of these five rows yet, so a fresh install delivers
# none of them, and SETUP-GUIDE.md has no Reviewer backend subsection.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INIT_SH="$PROJECT_ROOT/setup/init.sh"
MANIFEST="$PROJECT_ROOT/setup/manifest.json"
SETUP_GUIDE="$PROJECT_ROOT/setup/SETUP-GUIDE.md"

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
assert_true "AC-3a/AC-4: manifest ships .claude/autoflow.local.json as a scaffold artifact" \
  "jq -e '.artifacts[] | select(.source == \".claude/autoflow.local.json\" and .kind == \"scaffold\")' '$MANIFEST' >/dev/null 2>&1"

echo ""
echo "=== AC2e hash freshness (each new copy row's sha256 == current shasum of source) ==="

for src in scripts/review/codex-review-pr.sh scripts/preflight/check-review-backend.sh .codex/review.md; do
  if [ -f "$PROJECT_ROOT/$src" ]; then
    MANIFEST_HASH="$(jq -r --arg s "$src" '.artifacts[] | select(.source == $s) | .sha256 // empty' "$MANIFEST" 2>/dev/null)"
    ACTUAL_HASH="$(shasum -a 256 "$PROJECT_ROOT/$src" 2>/dev/null | awk '{print $1}')"
    assert_true "AC2e: manifest sha256 for $src matches current shasum" \
      "[ -n \"\$MANIFEST_HASH\" ] && [ \"\$MANIFEST_HASH\" = \"\$ACTUAL_HASH\" ]"
  else
    assert_true "AC2e: source $src exists" "false"
  fi
done

echo ""
echo "=== fresh mktemp install materializes all five artifacts + never-overwrite scaffold arm ==="

TARGET="$(mktemp -d)"
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
echo "=== SETUP-GUIDE.md Reviewer backend subsection (AC-4) ==="

assert_true "AC-4: SETUP-GUIDE.md Prerequisites documents a Reviewer backend subsection (codex default, claude opt-in, config file, fail-closed)" \
  "awk '/^## Prerequisites/{f=1;next} f && /^## /{exit} f' '$SETUP_GUIDE' | grep -qi 'reviewer backend'"

echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
