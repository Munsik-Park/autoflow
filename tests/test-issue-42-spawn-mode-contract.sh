#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: issue #42 — spawn-mode-by-lifetime contract (cycle-scoped L2 suite)
# =============================================================================
# Verification design: .autoflow/issue-42-verification-design.md §1 (L2 lane),
# §2 AC1/AC4 [MUST] (RED execution order), §5/§6 (Green judgment conditions).
#
# Permanent STATE invariants for AC1/AC2/AC3/AC6 (16 entries) live in the
# registry (tests/fixtures/doc-invariants.json, origin_issue 42) and run via
# tests/run-doc-invariants.sh — NOT duplicated here.
#
# This file carries only what the registry structurally cannot hold pre-GREEN
# (§2 AC1/AC4 [MUST]) plus DELTA-shaped / byte-invariance / meta guards:
#
#   42-AC1-* (9) / 42-AC4-* (3) — TEMPORARY discriminators (12 total). Their
#     `section` is a heading GREEN has not created yet (`### Spawn mode by
#     role lifetime` in CLAUDE.md, `### Result delivery path by spawn mode`
#     in docs/teammate-common-rules.md). Registering them in the permanent
#     registry before GREEN would make step 0b's dangling-anchor check BLOCK
#     the ENTIRE runner (exit 1), hiding every other origin_issue==42 entry's
#     individual FAIL (verification design §2 AC1 [MUST]). So RED expresses
#     them here as whole-file `grep -qF` failures, labeled with their FUTURE
#     registry entry id (verification design §2 AC1 [MUST] naming
#     convention), and GREEN promotes them into the registry in the SAME
#     commit that removes them from this file (§6 condition 1 checks this
#     via `grep -cE '42-(AC1|AC4)-' this-file` == 0 post-GREEN).
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
# RED expectation (this commit, docs not yet amended):
#   42-AC1-* (9) and 42-AC4-* (3) all FAIL (their section heading is absent).
#   AC2-UNTOUCHED, H-BYTES, M42-REGEN-CLEAN PASS (no diff yet / hook
#   untouched / manifest already clean).
#   A42-LITERAL-CONTIGUOUS (a) PASSes (no embedded newlines in any
#   origin_issue:42 literal). (b) FAILs for the 8 discriminator entries whose
#   text does not exist yet and PASSes for the 8 preservation-guard entries
#   already present pre-GREEN — a mixed, direction-aware result, matching the
#   registry's own discriminator/preservation split (verification design §3).
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

echo "=== issue #42 — spawn-mode-by-lifetime contract (cycle-scoped) ==="

# ---------------------------------------------------------------------------
# 42-AC1-* (9) / 42-AC4-* (3) — TEMPORARY discriminators, RED->L1 promotion
# pending (verification design §2 AC1/AC4 [MUST]). Whole-file grep because
# the section heading does not exist pre-GREEN.
# ---------------------------------------------------------------------------
echo ""
echo "42-AC1-* / 42-AC4-* — temporary pre-promotion discriminators (12)"

assert_true "42-AC1-must-marker: CLAUDE.md carries the [MUST] spawn-mode-fixed-by-lifetime sentence" \
  "grep -qF '**[MUST]** A role'\''s spawn mode is fixed by its lifetime requirement, not by its phase' '$CLAUDE_MD'"
assert_true "42-AC1-anon-eval: CLAUDE.md lists Evaluation AI (GATE:HYPOTHESIS/GATE:PLAN/AUDIT/GATE:QUALITY/VERIFY arbitration) as anonymous direct" \
  "grep -qF 'Evaluation AI (GATE:HYPOTHESIS structure/cause, GATE:PLAN, AUDIT, GATE:QUALITY, VERIFY arbitration) | anonymous direct' '$CLAUDE_MD'"
assert_true "42-AC1-anon-diagnose: CLAUDE.md lists the 5 DIAGNOSE spawns as anonymous direct" \
  "grep -qF 'DIAGNOSE (intake readiness triage, Phase A, Phase B, Phase 3, review-response loop check) | anonymous direct' '$CLAUDE_MD'"
assert_true "42-AC1-anon-handoff: CLAUDE.md scopes the HANDOFF row to ingestion/Low-judgment + digest emitter + PREFLIGHT scan" \
  "grep -qF 'HANDOFF review-triage subagent (finding ingestion + Low judgment, step 6.5), cycle digest emitter (6.7), PREFLIGHT cross-issue recurrence scan (1.5)' '$CLAUDE_MD'"
assert_true "42-AC1-handoff-scope: CLAUDE.md's HANDOFF row re-attributes auto-resolution re-entry to the named Test AI / Developer AI rows" \
  "grep -qF 'the auto-resolution it feeds is re-entered through the named Test AI / Developer AI rows' '$CLAUDE_MD'"
assert_true "42-AC1-named-lifetime: CLAUDE.md's named-spawn closed-set sentence is present" \
  "grep -qF 'Test AI and Developer AI are the only named spawns; every other role is anonymous direct.' '$CLAUDE_MD'"
assert_true "42-AC1-criterion: CLAUDE.md's decision rule is context-continuity, not invocation count" \
  "grep -qF 'Decision rule: must the role be re-entered retaining its prior call'\''s context? Yes — named team spawn; no — anonymous direct spawn.' '$CLAUDE_MD'"
assert_true "42-AC1-boundary-exception: CLAUDE.md names the VERIFY -> REFINE boundary respawn as the sole exception" \
  "grep -qF 'The VERIFY → REFINE boundary respawn is the sole exception' '$CLAUDE_MD'"
assert_true "42-AC1-workflow-excluded: CLAUDE.md excludes Workflow-based facilitation from both spawn modes" \
  "grep -qF 'facilitation (ARCHITECT, VERIFY cause-branch) is not an' '$CLAUDE_MD'"
assert_true "42-AC4-anon-return: docs/teammate-common-rules.md states the anonymous-mode delivery path" \
  "grep -qF 'the spawn'\''s return value (sync) or a task notification (background)' '$COMMON_RULES'"
assert_true "42-AC4-named-loss: docs/teammate-common-rules.md states the named-mode text is discarded" \
  "grep -qF 'discarded — never delivered to the lead' '$COMMON_RULES'"
assert_true "42-AC4-evidence-anchor: docs/teammate-common-rules.md cites the #40-cycle 12/12 observation as its evidence anchor" \
  "grep -qF 'Observed, not guaranteed: across all 12 subagents of the #40 cycle' '$COMMON_RULES'"

# ---------------------------------------------------------------------------
# AC2-UNTOUCHED — DELTA guard: PREFLIGHT 1.5 / HANDOFF 6.7 descriptions are
# untouched by this cycle's diff (verification design §2 AC2, fail-loud).
# ---------------------------------------------------------------------------
echo ""
echo "AC2-UNTOUCHED — PREFLIGHT step 1.5 / HANDOFF step 6.7 literals untouched by this cycle's diff"

BASE_REF="$(resolve_base_ref)"
if [ -z "$BASE_REF" ]; then
  echo "  FAIL: AC2-UNTOUCHED: resolve_base_ref could not resolve a comparison base (fail-loud, not SKIP)"
  FAIL=$((FAIL + 1))
else
  diff_touches_literal() {   # base file literal -> 0 (touched) / 1 (untouched)
    git -C "$PROJECT_ROOT" diff "$1" -- "$2" 2>/dev/null \
      | grep -E '^[+-]' \
      | grep -qF -- "$3"
  }
  if diff_touches_literal "$BASE_REF" "docs/autoflow-guide.md" "Cross-issue recurrence scan (step 1.5)"; then
    echo "  FAIL: AC2-UNTOUCHED: 'Cross-issue recurrence scan (step 1.5)' touched by this cycle's diff"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: AC2-UNTOUCHED: 'Cross-issue recurrence scan (step 1.5)' untouched by this cycle's diff"
    PASS=$((PASS + 1))
  fi
  if diff_touches_literal "$BASE_REF" "docs/autoflow-guide.md" "6.7. Cycle digest emission"; then
    echo "  FAIL: AC2-UNTOUCHED: '6.7. Cycle digest emission' touched by this cycle's diff"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: AC2-UNTOUCHED: '6.7. Cycle digest emission' untouched by this cycle's diff"
    PASS=$((PASS + 1))
  fi
fi

# ---------------------------------------------------------------------------
# H-BYTES — the gate hook and gate-schema fixture are byte-unchanged (AC5).
# ---------------------------------------------------------------------------
echo ""
echo "H-BYTES — the gate hook and gate-schema fixture are untouched (AC5)"

if [ -z "$BASE_REF" ]; then
  echo "  FAIL: H-BYTES: resolve_base_ref could not resolve a comparison base (fail-loud, not SKIP)"
  FAIL=$((FAIL + 1))
else
  assert_true "H-BYTES: hook and gate-schema.json are byte-unchanged vs base" \
    "git -C '$PROJECT_ROOT' diff --quiet '$BASE_REF' -- '$GATE_HOOK' '$GATE_SCHEMA'"
fi

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
# level-aware close). Re-derived rather than sourced (the runner's is a
# private function, not a library export) — same approach as
# tests/test-issue-40-doc-assertions.sh.
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

echo "  (info) A42-LITERAL-CONTIGUOUS (b): $DIRECTION_BAD/16 origin_issue:42 entries mismatch their predicate direction pre-GREEN (8 discriminators expected here; 8 preservation guards already match)"
assert_true "A42-LITERAL-CONTIGUOUS (b): exactly the 8 known discriminators mismatch pre-GREEN (expected Red; 0 expected post-GREEN)" \
  "[ \"$DIRECTION_BAD\" -eq 8 ]"

echo ""
echo "=============================="
echo "Results: $((PASS + FAIL)) total, $PASS passed, $FAIL failed"
echo "=============================="
[[ $FAIL -eq 0 ]]
