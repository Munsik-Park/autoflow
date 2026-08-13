#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: issue #42 — spawn-mode-by-lifetime contract (cycle-scoped L2 suite)
# =============================================================================
# Verification design: .autoflow/issue-42-verification-design.md §1 (L2 lane),
# §2 AC1/AC4 [MUST] (RED execution order), §5/§6 (Green judgment conditions).
#
# Permanent STATE invariants for AC1/AC2/AC3/AC4/AC6 (24 entries) live in the
# registry (tests/fixtures/doc-invariants.json, origin_issue 42) and run via
# tests/run-doc-invariants.sh — NOT duplicated here. (Issue #74's spawn-mode
# migration retired 4 of the 28: the passages they pinned — the role-prefix
# notation, the two-mode decision rule, the "only named spawns" sentence, the
# VERIFY→REFINE "sole exception" clause — no longer exist post-migration, per
# docs/doc-invariant-registry.md §10. The remaining 24 were re-pointed in
# place, not retired.)
#
# The 12 discriminators this file carried at RED (9 for AC1, 3 for AC4) were
# TEMPORARY. Their `section` was a heading GREEN had not created yet
# (`### Spawn mode by role lifetime` in CLAUDE.md, `### Result delivery path
# by spawn mode` in docs/teammate-common-rules.md), and registering them
# before GREEN would have made step 0b's dangling-anchor check BLOCK the
# ENTIRE runner (exit 1), hiding every other origin_issue==42 entry's
# individual FAIL. GREEN created both headings and promoted all 12 into the
# permanent registry in the SAME commit that deleted them from this file, so
# the registry count moved 16 -> 28 and this file now holds none of them.
#
# What remains here is only what the registry structurally cannot hold —
# DELTA-shaped / byte-invariance / meta guards:
#
#   AC2-UNTOUCHED  — DELTA guard: this cycle's diff does not touch the
#     PREFLIGHT step-1.5 / HANDOFF step-6.7 descriptions in
#     docs/autoflow-guide.md (resolve_base_ref, fail-loud, never SKIP).
#   H-BYTES        — the gate hook and gate-schema fixture are byte-unchanged
#     (AC5).
#   M42-REGEN-CLEAN — setup/manifest.json stays regen-clean for the 6 docs
#     this cycle edits (docs/gate-matching-standard.md is NOT a manifest
#     source — verified separately below).
#   A42-LITERAL-CONTIGUOUS — cross-cutting meta guard on the registry append
#     itself: (a) no origin_issue:42 literal/before/after carries an embedded
#     newline, (b) each is re-checked against its target file in the
#     PREDICATE-APPROPRIATE direction (present/ordered -> found; absent ->
#     NOT found) with the grep flavor the entry's own `match` field selects.
#
# Green expectation (post-promotion): every assertion PASSes. All 24
# origin_issue:42 entries now resolve in their own predicate's direction, so
# A42-LITERAL-CONTIGUOUS (b) expects DIRECTION_BAD == 0 over 24 entries — the
# promotion's own oracle. A non-zero value means a promoted literal does not
# match its target file, or a preservation guard was broken by this cycle's
# edits.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$SCRIPT_DIR/lib/base-ref.sh"

REGISTRY="$SCRIPT_DIR/fixtures/doc-invariants.json"
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
GUIDE="$PROJECT_ROOT/docs/autoflow-guide.md"
COMMON_RULES="$PROJECT_ROOT/docs/teammate-common-rules.md"
MANIFEST="$PROJECT_ROOT/setup/manifest.json"
GEN_MANIFEST="$PROJECT_ROOT/setup/gen-manifest-hashes.sh"
GATE_HOOK="$PROJECT_ROOT/.claude/hooks/check-autoflow-gate.sh"

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

echo "=== issue #42 — spawn-mode-by-lifetime contract (cycle-scoped) ==="

# AC2-UNTOUCHED (retired, #71): the two docs/autoflow-guide.md literal fences
# were a #42 cycle-scope DELTA seal over regions that #71 legitimately deletes;
# once the guarded region is gone the fence has no surviving subject. Retired
# on the H-BYTES precedent below.

# H-BYTES (retired, #64): the "hook byte-unchanged vs base" fence was a #42
# cycle-scope seal; it blocked every legitimate later hook change (change-
# detector anti-pattern) and was removed in the #64 hook-fix PR.

# ---------------------------------------------------------------------------
# M42-REGEN-CLEAN — manifest stays regen-clean (docs/gate-matching-standard.md
# is NOT a manifest source, so its edit does not require a manifest refresh).
# ---------------------------------------------------------------------------
echo ""
echo "M42-REGEN-CLEAN — setup/manifest.json is regen-clean"

assert_true "M42-REGEN-CLEAN: docs/gate-matching-standard.md is not a manifest-registered artifact source" \
  "[ \"\$(jq -r '.artifacts[].source' '$MANIFEST' | grep -c '^docs/gate-matching-standard.md$')\" -eq 0 ]"

if [ -x "$GEN_MANIFEST" ] || [ -f "$GEN_MANIFEST" ]; then
  cp "$MANIFEST" "$MANIFEST.bak-issue42"
  ( cd "$PROJECT_ROOT" && bash "$GEN_MANIFEST" >/dev/null 2>&1 )
  assert_true "M42-REGEN-CLEAN: regenerating setup/manifest.json produces no diff" \
    "diff -q '$MANIFEST' '$MANIFEST.bak-issue42' >/dev/null 2>&1"
  mv "$MANIFEST.bak-issue42" "$MANIFEST"
else
  echo "  FAIL: M42-REGEN-CLEAN: setup/gen-manifest-hashes.sh not found"
  FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
# A42-LITERAL-CONTIGUOUS — meta guard on the registry append itself.
# (a) no embedded newline. (b) predicate-direction-aware re-check, grep
# flavor per entry `match` (verification design's横断 [MUST]).
# ---------------------------------------------------------------------------
echo ""
echo "A42-LITERAL-CONTIGUOUS — no origin_issue:42 registry literal carries an embedded newline, and each re-checks in its predicate's direction"

NEWLINE_BAD=$(jq -r '
  [.invariants[] | select(.origin_issue==42) |
    ((.literal // "") + " " + (.before // "") + " " + (.after // ""))] |
  map(select(contains("\n"))) | length
' "$REGISTRY")
assert_true "A42-LITERAL-CONTIGUOUS (a): no origin_issue:42 literal/before/after contains an embedded newline" \
  "[ \"$NEWLINE_BAD\" = 0 ]"

# extract_section mirrors tests/run-doc-invariants.sh's own (durable heading,
# level-aware close). Re-derived rather than sourced: the runner's is a
# private function, not a library export.
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
  local body="$1" literal="$2" match="$3"
  if [ "$match" = "regex" ]; then
    grep -qE -- "$literal" <<<"$body"
  else
    grep -qF -- "$literal" <<<"$body"
  fi
}

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
done < <(jq -r '.invariants[] | select(.origin_issue==42) |
  [.id, .file, (.section // ""), .predicate, (.match // "fixed"),
   (if .predicate=="ordered" then .before else .literal end),
   (.after // "")] | @tsv' "$REGISTRY")

echo "  (info) A42-LITERAL-CONTIGUOUS (b): $DIRECTION_BAD/24 origin_issue:42 entries mismatch their predicate direction post-GREEN (0 expected — issue #74 retired the other 4 of the original 28, docs/doc-invariant-registry.md §10)"
assert_true "A42-LITERAL-CONTIGUOUS (b): every origin_issue:42 entry matches its predicate direction (0 expected post-GREEN)" \
  "[ \"$DIRECTION_BAD\" -eq 0 ]"

echo ""
echo "=============================="
echo "Results: $((PASS + FAIL)) total, $PASS passed, $FAIL failed"
echo "=============================="
[[ $FAIL -eq 0 ]]
