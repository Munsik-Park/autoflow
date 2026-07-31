#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: issue #40 cycle-scoped doc assertions (consider-the-opposite pre-scoring)
# =============================================================================
# Verification design: .autoflow/issue-40-verification-design.md §3/§6.
# Permanent STATE invariants for AC1/AC2/AC3/AC5/AC6 live in the registry
# (tests/fixtures/doc-invariants.json, origin_issue 40) and run via
# tests/run-doc-invariants.sh — NOT duplicated here (docs/doc-invariant-registry.md
# §1: a permanent invariant is a registry data append, never a per-issue script).
#
# This file carries only what the registry cannot: DELTA-shaped and
# cycle-local assertions that retire at merge (docs/doc-invariant-registry.md §2).
#
# AC coverage (verification design §6 Red-discriminator plan):
#   A1-DENY-COMPAT       — preservation guard: the pre-existing Finding
#                          coverage [MUST] (docs/teammate-contracts.md:19) is
#                          not narrowed by the new survivor-routing clause.
#   A2-JSON-VALID        — preservation guard: both Evaluation Output Format
#                          fenced blocks still parse as JSON.
#   A2-PARITY            — preservation guard: the two fenced blocks stay
#                          byte-identical (DELTA-shaped, cannot live in the
#                          registry per doc-invariant-registry.md §1; the
#                          per-field STATE parity is carried by the registry's
#                          40-AC2-field-in-format / 40-AC2-field-in-contracts).
#   A6-EVALSYS-ROW       — preservation guard: the Evaluation System row's
#                          existing "output format change" trigger still
#                          covers AC2 after the widening.
#   A6-PROCEDURE-TRIGGER — discriminator: the widened trigger clause names
#                          the new pre-scoring *procedure*, not just the
#                          output format.
#   A-LITERAL-CONTIGUOUS — cross-cutting meta guard (verification design §3):
#                          every origin_issue:40 registry literal (a) carries
#                          no embedded newline (silent grep -F OR-of-patterns
#                          degradation, run-doc-invariants.sh:117-122) and
#                          (b) is re-checked with grep -qF against the
#                          IMPLEMENTED file before being trusted — this half
#                          FAILS pre-GREEN (the sections do not exist yet),
#                          which is expected Red for this meta guard.
#   AC4-DELTA            — discriminator/guard: the Evaluation AI section and
#                          PASS Criteria / Evaluation Types blocks are
#                          untouched by this cycle's diff (resolve_base_ref,
#                          fail-loud, never SKIP — docs/doc-invariant-registry.md §4).
#   M-REGEN-CLEAN        — preservation guard now / discriminator against a
#                          forgotten manifest refresh later: setup/manifest.json
#                          stays regen-clean for the four docs this cycle edits.
#
# RED expectation (this commit, docs not yet amended):
#   A1-DENY-COMPAT, A2-JSON-VALID, A2-PARITY, A6-EVALSYS-ROW, M-REGEN-CLEAN,
#   AC4-DELTA all PASS today (preservation guards / no diff yet).
#   A6-PROCEDURE-TRIGGER FAILs today (the widened trigger clause is absent).
#   A-LITERAL-CONTIGUOUS's newline check PASSes; its implemented-file re-check
#   FAILs today (the target sections do not exist yet) — expected Red.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$SCRIPT_DIR/lib/base-ref.sh"

REGISTRY="$SCRIPT_DIR/fixtures/doc-invariants.json"
CONTRACTS="$PROJECT_ROOT/docs/teammate-contracts.md"
EVALSYS="$PROJECT_ROOT/docs/evaluation-system.md"
MAINTAINED="$PROJECT_ROOT/docs/maintained-docs.md"
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
MANIFEST="$PROJECT_ROOT/setup/manifest.json"
GEN_MANIFEST="$PROJECT_ROOT/setup/gen-manifest-hashes.sh"

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

assert_false() {
  local desc="$1"; shift
  if eval "$1"; then
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

# Section extractor mirroring tests/run-doc-invariants.sh's own (durable
# heading, level-aware close). Re-derived rather than sourced, since the
# runner's is a private function, not a library export.
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

# Fenced-JSON-block extractor: first ```json ... ``` fence inside a section.
extract_fence() {            # section_body
  awk '/^```/{c++; if(c==1){next}; if(c==2){exit}} c==1{print}' <<<"$1"
}

echo "=== issue #40 — cycle-scoped doc assertions ==="

# ---------------------------------------------------------------------------
# A1-DENY-COMPAT — preservation guard
# ---------------------------------------------------------------------------
echo ""
echo "A1-DENY-COMPAT — Finding coverage recall guard is extended, not narrowed"

FINDING_BODY="$(extract_section "Finding coverage (model-recall guard)" "$CONTRACTS")"
assert_true "A1-DENY-COMPAT: Finding coverage [MUST] still lists every finding in recommendations/blocking_issues with no band restriction" \
  "grep -qF 'list them in \`recommendations\` (or \`blocking_issues\` when score-blocking)' <<<\"\$FINDING_BODY\""
assert_true "A1-DENY-COMPAT: the [DENY] against conservative filtering at the finding stage is still present" \
  "grep -qF 'only report important/high-severity issues' <<<\"\$FINDING_BODY\""

# ---------------------------------------------------------------------------
# A2-JSON-VALID / A2-PARITY — preservation guards
# ---------------------------------------------------------------------------
echo ""
echo "A2-JSON-VALID / A2-PARITY — both Evaluation Output Format blocks parse and stay identical"

FMT_CONTRACTS="$(extract_fence "$(extract_section "Evaluation Output Format" "$CONTRACTS")")"
FMT_EVALSYS="$(extract_fence "$(extract_section "Evaluation Output Format" "$EVALSYS")")"

assert_true "A2-JSON-VALID: teammate-contracts.md Evaluation Output Format fence parses as JSON" \
  "jq -e . >/dev/null 2>&1 <<<\"\$FMT_CONTRACTS\""
assert_true "A2-JSON-VALID: evaluation-system.md Evaluation Output Format fence parses as JSON" \
  "jq -e . >/dev/null 2>&1 <<<\"\$FMT_EVALSYS\""

NORM_CONTRACTS="$(jq -S -c . <<<"$FMT_CONTRACTS" 2>/dev/null)"
NORM_EVALSYS="$(jq -S -c . <<<"$FMT_EVALSYS" 2>/dev/null)"
assert_true "A2-PARITY: the two Evaluation Output Format blocks are structurally identical (key-sorted)" \
  "[ -n \"\$NORM_CONTRACTS\" ] && [ \"\$NORM_CONTRACTS\" = \"\$NORM_EVALSYS\" ]"

# ---------------------------------------------------------------------------
# A6-EVALSYS-ROW (preservation) / A6-PROCEDURE-TRIGGER (discriminator)
# ---------------------------------------------------------------------------
echo ""
echo "A6 — maintained-docs.md Evaluation System row"

METHOD_BODY="$(extract_section "Methodology docs (\`docs/\`)" "$MAINTAINED")"
EVALSYS_ROW="$(grep -F 'docs/evaluation-system.md' <<<"$METHOD_BODY" || true)"

assert_true "A6-EVALSYS-ROW: Evaluation System row still triggers on output format change (preservation)" \
  "grep -qF 'output format change' <<<\"\$EVALSYS_ROW\""
assert_true "A6-PROCEDURE-TRIGGER: Evaluation System row's trigger names the pre-scoring evaluation procedure [discriminator — FAILs pre-GREEN]" \
  "grep -qF 'pre-scoring evaluation procedure' <<<\"\$EVALSYS_ROW\""

# ---------------------------------------------------------------------------
# A-LITERAL-CONTIGUOUS — cross-cutting meta guard on the registry append itself
# ---------------------------------------------------------------------------
echo ""
echo "A-LITERAL-CONTIGUOUS — no origin_issue:40 registry literal carries an embedded newline, and each matches the implemented file"

NEWLINE_BAD=$(jq -r '
  [.invariants[] | select(.origin_issue==40) |
    ((.literal // "") + " " + (.before // "") + " " + (.after // ""))] |
  map(select(contains("\n"))) | length
' "$REGISTRY")
assert_true "A-LITERAL-CONTIGUOUS (a): no origin_issue:40 literal/before/after contains an embedded newline" \
  "[ \"$NEWLINE_BAD\" = 0 ]"

# (b) Re-derive each entry's target file body and grep -qF it directly — the
# same silent-degradation guard the verification design's §3 [MUST] requires
# before an append is trusted. This intentionally reads the CURRENT (possibly
# pre-GREEN) file state, so it FAILS now and PASSes once GREEN lands the text.
IMPL_MISMATCH=0
while IFS=$'\t' read -r id file section literal before after; do
  [ -n "$id" ] || continue
  srcfile="$PROJECT_ROOT/$file"
  if [ -n "$section" ]; then
    body="$(extract_section "$section" "$srcfile" 2>/dev/null)"
  else
    body="$(cat "$srcfile" 2>/dev/null)"
  fi
  if [ -n "$literal" ]; then
    grep -qF -- "$literal" <<<"$body" || IMPL_MISMATCH=$((IMPL_MISMATCH + 1))
  else
    grep -qF -- "$before" <<<"$body" || IMPL_MISMATCH=$((IMPL_MISMATCH + 1))
    grep -qF -- "$after" <<<"$body" || IMPL_MISMATCH=$((IMPL_MISMATCH + 1))
  fi
done < <(jq -r '.invariants[] | select(.origin_issue==40) |
  [.id, .file, (.section // ""), (.literal // ""), (.before // ""), (.after // "")] | @tsv' "$REGISTRY")

assert_true "A-LITERAL-CONTIGUOUS (b): every origin_issue:40 literal re-checks against the implemented file [expected FAIL pre-GREEN]" \
  "[ \"$IMPL_MISMATCH\" -eq 0 ]"

# ---------------------------------------------------------------------------
# AC4-DELTA — this cycle's diff does not touch the Evaluation AI rubric
# thresholds / item counts / regression caps (fail-loud, never SKIP).
# ---------------------------------------------------------------------------
echo ""
echo "AC4-DELTA — thresholds / item counts / regression caps untouched by this cycle's diff"

BASE_REF="$(resolve_base_ref)"
if [ -z "$BASE_REF" ]; then
  echo "  FAIL: AC4-DELTA: resolve_base_ref could not resolve a comparison base (fail-loud, not SKIP)"
  FAIL=$((FAIL + 1))
else
  threshold_diff_touched() {   # base file -> 0 (untouched) / 1 (touched)
    git -C "$PROJECT_ROOT" diff "$1" -- "$2" 2>/dev/null \
      | grep -E '^[+-]' \
      | grep -qE 'Average.{1,3}7\.5|Each item.{1,3}7|Security.{1,3}3|max 2×|max 3×|one revision'
  }
  assert_false "AC4-DELTA: docs/teammate-contracts.md PASS Criteria / Evaluation Types thresholds untouched vs base" \
    "threshold_diff_touched '$BASE_REF' docs/teammate-contracts.md"
  assert_false "AC4-DELTA: CLAUDE.md Regressions caps untouched vs base" \
    "threshold_diff_touched '$BASE_REF' CLAUDE.md"
  assert_true "AC4-DELTA (H-BYTES companion): the gate hook itself is byte-unchanged vs base" \
    "git -C '$PROJECT_ROOT' diff --quiet '$BASE_REF' -- .claude/hooks/check-autoflow-gate.sh tests/fixtures/gate-schema.json"
fi

# ---------------------------------------------------------------------------
# M-REGEN-CLEAN — manifest stays regen-clean (preservation now; discriminator
# against a forgotten refresh once GREEN edits the four docs).
# ---------------------------------------------------------------------------
echo ""
echo "M-REGEN-CLEAN — setup/manifest.json is regen-clean"

if [ -x "$GEN_MANIFEST" ] || [ -f "$GEN_MANIFEST" ]; then
  cp "$MANIFEST" "$MANIFEST.bak-issue40"
  ( cd "$PROJECT_ROOT" && bash "$GEN_MANIFEST" >/dev/null 2>&1 )
  assert_true "M-REGEN-CLEAN: regenerating setup/manifest.json produces no diff" \
    "diff -q '$MANIFEST' '$MANIFEST.bak-issue40' >/dev/null 2>&1"
  mv "$MANIFEST.bak-issue40" "$MANIFEST"
else
  echo "  FAIL: M-REGEN-CLEAN: setup/gen-manifest-hashes.sh not found"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "=============================="
echo "Results: $((PASS + FAIL)) total, $PASS passed, $FAIL failed"
echo "=============================="
[[ $FAIL -eq 0 ]]
