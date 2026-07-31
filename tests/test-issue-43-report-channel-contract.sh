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
# RED STATE (this commit): the 10 discriminators below are TEMPORARY. They
# stage the 9 `present`-direction + 1 `ordered` literals that do not yet exist
# in the live tree (verification design §5.0 rows 1, 2, 4, 5, 8-13). GREEN
# appends all 15 ratified entries to tests/fixtures/doc-invariants.json
# (origin_issue: 43) in the SAME commit that deletes these 10 discriminators
# from this file — each literal moves exactly once. The 5 already-green rows
# (3, 6, 7, 14, 15 — preservation / scoping guards) are NOT staged here; they
# carry no RED signal and enter the registry directly at GREEN.
#
# What remains here permanently (does not delete at GREEN) — DELTA-shaped /
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
#     `match` flavor (DIRECTION_BAD == 0). Vacuously passes at RED (zero
#     origin_issue:43 entries exist yet) — the real check runs at GREEN.
#   S43-UNTOUCHED          — this cycle's diff touches none of the three
#     asserted non-edits: docs/teammate-common-rules.md,
#     .claude/agents/autoflow-*.md, docs/maintained-docs.md.
#
# Expected RED verdict: 11 FAIL (the 10 staged literals + R43-COUNT reading
# 0 != 15). H43-BYTES, M43-REGEN-CLEAN, S43-UNTOUCHED PASS; the 5 unstaged
# preservation/scoping rows are green at HEAD by design and are not counted
# as a RED shortfall.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
. "$SCRIPT_DIR/lib/base-ref.sh"

REGISTRY="$SCRIPT_DIR/fixtures/doc-invariants.json"
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
CONTRACTS="$PROJECT_ROOT/docs/teammate-contracts.md"
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

first_line_of() {            # body literal match -> line number or empty
  local body="$1" literal="$2" match="${3:-fixed}" out
  if [ "$match" = "regex" ]; then
    out="$(grep -nE -- "$literal" <<<"$body" || true)"
  else
    out="$(grep -nF -- "$literal" <<<"$body" || true)"
  fi
  printf '%s\n' "$out" | head -1 | cut -d: -f1
}

echo "=== issue #43 — report-channel contract (cycle-scoped) ==="

# ---------------------------------------------------------------------------
# Staged discriminators (verification design §5.0, rows 1,2,4,5,8-13).
# TEMPORARY — deleted at GREEN promotion into tests/fixtures/doc-invariants.json.
# ---------------------------------------------------------------------------
echo ""
echo "AC1 — docs/teammate-contracts.md: SendMessage [MUST] clause in the named-role sections (staged)"

TESTAI_BODY="$(extract_section "Test AI (testing teammate)" "$CONTRACTS")"
DEVAI_BODY="$(extract_section "Submodule AI (per sub-repo, Developer AI)" "$CONTRACTS")"

assert_true "43-AC1-testai-channel: Test AI section carries the SendMessage [MUST] channel clause" \
  "body_has \"\$TESTAI_BODY\" '**[MUST]** Reports to the orchestrator via \`SendMessage(to: \"team-lead\")\`'"
assert_true "43-AC1-testai-pointer: Test AI section points to Result delivery path by spawn mode" \
  "body_has \"\$TESTAI_BODY\" 'Result delivery path by spawn mode'"
assert_true "43-AC1-devai-channel: Submodule AI section carries the SendMessage [MUST] channel clause" \
  "body_has \"\$DEVAI_BODY\" '**[MUST]** Reports to the orchestrator via \`SendMessage(to: \"team-lead\")\`'"
assert_true "43-AC1-devai-pointer: Submodule AI section points to Result delivery path by spawn mode" \
  "body_has \"\$DEVAI_BODY\" 'Result delivery path by spawn mode'"

echo ""
echo "AC2 — CLAUDE.md > Execution Principles: [DENY] on the final-message idiom + summary-absent idle reading (staged)"

EXEC_BODY="$(extract_section "Execution Principles" "$CLAUDE_MD")"

assert_true "43-AC2-deny-marker: Execution Principles carries a standalone [DENY] marker" \
  "body_has \"\$EXEC_BODY\" '**[DENY]**'"
assert_true "43-AC2-deny-scope: the DENY clause names the mode it binds (named team spawn)" \
  "body_has \"\$EXEC_BODY\" 'named team spawn'"
assert_true "43-AC2-idiom-anon-only: the final-message idiom is scoped to anonymous direct spawns only" \
  "body_has \"\$EXEC_BODY\" 'idiom belongs to anonymous direct spawns only'"
assert_true "43-AC2-summary-absent: a summary-absent idle notification reads as report not sent" \
  "body_has \"\$EXEC_BODY\" 'a notification with no \`summary\` field reads as **report not sent**'"
assert_true "43-AC2-recovery-path: the recovery path names re-requesting the report with SendMessage" \
  "body_has \"\$EXEC_BODY\" 're-requesting the report with \`SendMessage\`'"
assert_true "43-AC2-idle-order: 'Teammate idle handling' precedes 'Named-spawn non-delivery reading'" \
  "{ bln=\$(first_line_of \"\$EXEC_BODY\" 'Teammate idle handling'); aln=\$(first_line_of \"\$EXEC_BODY\" 'Named-spawn non-delivery reading'); [ -n \"\$bln\" ] && [ -n \"\$aln\" ] && [ \"\$bln\" -lt \"\$aln\" ]; }"

# ---------------------------------------------------------------------------
# H43-BYTES — the gate hook and gate-schema fixture are byte-unchanged (AC3).
# ---------------------------------------------------------------------------
echo ""
echo "H43-BYTES — the gate hook and gate-schema fixture are untouched (AC3)"

BASE_REF="$(resolve_base_ref)"
if [ -z "$BASE_REF" ]; then
  echo "  FAIL: H43-BYTES: resolve_base_ref could not resolve a comparison base (fail-loud, not SKIP)"
  FAIL=$((FAIL + 1))
else
  assert_true "H43-BYTES: hook and gate-schema.json are byte-unchanged vs base" \
    "git -C '$PROJECT_ROOT' diff --quiet '$BASE_REF' -- '$GATE_HOOK' '$GATE_SCHEMA'"
fi

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
# flavor per entry `match`. Vacuously PASSes at RED (0 entries exist yet) —
# the real check runs post-GREEN-promotion over 15 entries.
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

echo "  (info) A43-LITERAL-CONTIGUOUS (b): $DIRECTION_BAD/$COUNT43 origin_issue:43 entries mismatch their predicate direction (0 expected post-GREEN over 15)"
assert_true "A43-LITERAL-CONTIGUOUS (b): every origin_issue:43 entry matches its predicate direction (vacuous PASS at RED, 0 expected post-GREEN)" \
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
