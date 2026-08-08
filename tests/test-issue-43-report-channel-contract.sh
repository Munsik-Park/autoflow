#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: issue #43 — reporting-channel contract for the residual mailbox roles
# (cycle-scoped L2 suite)
# =============================================================================
# Verification design: .autoflow/issue-43-verification-design.md §1 (L2 lane),
# §5.0 (ratified 15-entry set), §6 (RED execution order [MUST]), §7 (Green
# judgment conditions).
#
# GREEN STATE (this commit): the 10 temporary discriminators are DELETED. All
# 15 ratified entries (verification design §5.0) now live in
# tests/fixtures/doc-invariants.json under origin_issue: 43 — each literal
# moved exactly once, so R43-COUNT reads 15 and the permanent runner
# (tests/run-doc-invariants.sh) owns every STATE-shaped assertion.
#
# What remains here permanently — DELTA-shaped /
# byte-invariance / count / meta guards the permanent registry structurally
# cannot hold (tests/run-doc-invariants.sh rejects any predicate outside
# present|absent|ordered):
#
#   H43-BYTES              — the gate hook and gate-schema fixture are
#     byte-unchanged (AC3; the reporting channel is not hook-enforced —
#     barred by the declared-role rule, not unobservable).
#   M43-REGEN-CLEAN        — setup/manifest.json stays regen-clean for the
#     two manifest-registered sources this cycle edits (CLAUDE.md,
#     docs/teammate-contracts.md).
#   R43-COUNT              — the origin_issue==43 registry entry count is
#     exactly 15 (count-shaped; the registry cannot hold a count predicate).
#   A43-LITERAL-CONTIGUOUS — meta guard over the append: (a) no
#     origin_issue:43 literal/before/after carries an embedded newline,
#     (b) each entry re-checks in its OWN predicate's direction with its own
#     `match` flavor (DIRECTION_BAD == 0), over all 15 promoted entries.
#   S43-UNTOUCHED          — this cycle's diff touches none of the three
#     asserted non-edits: docs/teammate-common-rules.md,
#     .claude/agents/autoflow-*.md, docs/maintained-docs.md.
#
# Expected verdict post-GREEN: 0 FAIL.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$SCRIPT_DIR/lib/base-ref.sh"

REGISTRY="$SCRIPT_DIR/fixtures/doc-invariants.json"
MANIFEST="$PROJECT_ROOT/setup/manifest.json"
GEN_MANIFEST="$PROJECT_ROOT/setup/gen-manifest-hashes.sh"
GATE_HOOK="$PROJECT_ROOT/.claude/hooks/check-autoflow-gate.sh"
GATE_SCHEMA="$PROJECT_ROOT/tests/fixtures/gate-schema.json"

PASS=0
FAIL=0

assert_true() {
  local desc="$1"; shift
  if eval "$1"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

# extract_section mirrors tests/run-doc-invariants.sh's own (durable heading,
# level-aware close, bare-`---` thematic-break terminator). Re-derived rather
# than sourced (the runner's is a private function, not a library export) —
# same approach as tests/test-issue-42-spawn-mode-contract.sh.
extract_section() {          # heading_text file
  local heading="$1" file="$2"
  awk -v h="$heading" '
    function level(line,   n){ n=0; while(substr(line,n+1,1)=="#") n++; return n }
    !f && /^#{1,6} +/ {
      t=$0; sub(/^#{1,6} +/,"",t); sub(/[ \t]+$/,"",t)
      if (t==h) { f=1; L=level($0); next }
    }
    f {
      if (/^#{1,6} +/ && level($0)<=L)      { f=0; next }
      else if (/^---[ \t]*$/)               { f=0; next }
      else print
    }
  ' "$file"
}

body_has() {                 # body literal match
  local body="$1" literal="$2" match="${3:-fixed}"
  if [ "$match" = "regex" ]; then
    grep -qE -- "$literal" <<<"$body"
  else
    grep -qF -- "$literal" <<<"$body"
  fi
}

echo "=== issue #43 — report-channel contract (cycle-scoped) ==="

# H43-BYTES (retired, #64): the "hook byte-unchanged vs base" fence was a #43
# cycle-scope seal; it blocked every legitimate later hook change (change-
# detector anti-pattern) and was removed in the #64 hook-fix PR. BASE_REF is
# still resolved here because later sections consume it.
BASE_REF="$(resolve_base_ref)"

# ---------------------------------------------------------------------------
# M43-REGEN-CLEAN — manifest stays regen-clean for the two manifest-registered
# sources this cycle edits (CLAUDE.md, docs/teammate-contracts.md).
# docs/maintained-docs.md is NOT edited this cycle (D3 ratified as (i),
# check-only) and is therefore not a third regen source.
# ---------------------------------------------------------------------------
echo ""
echo "M43-REGEN-CLEAN — setup/manifest.json is regen-clean"

if [ -x "$GEN_MANIFEST" ] || [ -f "$GEN_MANIFEST" ]; then
  cp "$MANIFEST" "$MANIFEST.bak-issue43"
  ( cd "$PROJECT_ROOT" && bash "$GEN_MANIFEST" >/dev/null 2>&1 )
  assert_true "M43-REGEN-CLEAN: regenerating setup/manifest.json produces no diff" \
    "diff -q '$MANIFEST' '$MANIFEST.bak-issue43' >/dev/null 2>&1"
  mv "$MANIFEST.bak-issue43" "$MANIFEST"
else
  echo "  FAIL: M43-REGEN-CLEAN: setup/gen-manifest-hashes.sh not found"
  FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
# R43-COUNT — origin_issue==43 entry count equals 15 (D2/§5.0 ratified set).
# Count-shaped -> cycle-scoped only, never in the permanent registry.
# ---------------------------------------------------------------------------
echo ""
echo "R43-COUNT — origin_issue==43 registry entry count is exactly 15"

COUNT43=$(jq -r '[.invariants[] | select(.origin_issue==43)] | length' "$REGISTRY")
assert_true "R43-COUNT: origin_issue==43 entry count == 15 (currently $COUNT43)" \
  "[ \"$COUNT43\" -eq 15 ]"

# ---------------------------------------------------------------------------
# A43-LITERAL-CONTIGUOUS — meta guard on the registry append itself.
# (a) no embedded newline. (b) predicate-direction-aware re-check, grep
# flavor per entry `match`, over the 15 promoted entries.
# ---------------------------------------------------------------------------
echo ""
echo "A43-LITERAL-CONTIGUOUS — no origin_issue:43 registry literal carries an embedded newline, and each re-checks in its predicate's direction"

NEWLINE_BAD=$(jq -r '
  [.invariants[] | select(.origin_issue==43) |
    ((.literal // "") + " " + (.before // "") + " " + (.after // ""))] |
  map(select(contains("\n"))) | length
' "$REGISTRY")
assert_true "A43-LITERAL-CONTIGUOUS (a): no origin_issue:43 literal/before/after contains an embedded newline" \
  "[ \"$NEWLINE_BAD\" = 0 ]"

DIRECTION_BAD=0
while IFS=$'\t' read -r id file section predicate match literal after; do
  [ -n "$id" ] || continue
  srcfile="$PROJECT_ROOT/$file"
  if [ -n "$section" ]; then
    body="$(extract_section "$section" "$srcfile" 2>/dev/null)"
  else
    body="$(cat "$srcfile" 2>/dev/null)"
  fi
  case "$predicate" in
    present)
      body_has "$body" "$literal" "$match" || DIRECTION_BAD=$((DIRECTION_BAD + 1))
      ;;
    ordered)
      { body_has "$body" "$literal" "$match" && body_has "$body" "$after" "$match"; } \
        || DIRECTION_BAD=$((DIRECTION_BAD + 1))
      ;;
    absent)
      body_has "$body" "$literal" "$match" && DIRECTION_BAD=$((DIRECTION_BAD + 1))
      ;;
  esac
done < <(jq -r '.invariants[] | select(.origin_issue==43) |
  [.id, .file, (.section // ""), .predicate, (.match // "fixed"),
   (if .predicate=="ordered" then .before else .literal end),
   (.after // "")] | @tsv' "$REGISTRY")

echo "  (info) A43-LITERAL-CONTIGUOUS (b): $DIRECTION_BAD/$COUNT43 origin_issue:43 entries mismatch their predicate direction (0 expected)"
assert_true "A43-LITERAL-CONTIGUOUS (b): every origin_issue:43 entry matches its predicate direction" \
  "[ \"$DIRECTION_BAD\" -eq 0 ]"

# ---------------------------------------------------------------------------
# S43-UNTOUCHED — this cycle's diff touches none of the three asserted
# non-edits (feature design §2 Not changed; verification design D6).
# ---------------------------------------------------------------------------
echo ""
echo "S43-UNTOUCHED — this cycle's diff does not touch the three asserted non-edit surfaces"

if [ -z "$BASE_REF" ]; then
  echo "  FAIL: S43-UNTOUCHED: resolve_base_ref could not resolve a comparison base (fail-loud, not SKIP)"
  FAIL=$((FAIL + 1))
else
  CHANGED_FILES="$(git -C "$PROJECT_ROOT" diff "$BASE_REF"...HEAD --name-only 2>/dev/null)"
  UNTOUCHED_BAD=0
  for pattern in 'docs/teammate-common-rules.md' '.claude/agents/autoflow-.*\.md' 'docs/maintained-docs.md'; do
    if printf '%s\n' "$CHANGED_FILES" | grep -qE -- "^${pattern}$"; then
      UNTOUCHED_BAD=$((UNTOUCHED_BAD + 1))
      echo "  (info) S43-UNTOUCHED: diff touches a file matching '$pattern'"
    fi
  done
  assert_true "S43-UNTOUCHED: diff contains none of the three asserted non-edit surfaces" \
    "[ \"$UNTOUCHED_BAD\" -eq 0 ]"
fi

echo ""
echo "=============================="
echo "Results: $((PASS + FAIL)) total, $PASS passed, $FAIL failed"
echo "=============================="
[[ $FAIL -eq 0 ]]
