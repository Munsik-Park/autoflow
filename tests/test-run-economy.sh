#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: docs/autoflow-guide.md docs/teammate-common-rules.md .claude/agents/autoflow-implementer.md plugin/autoflow/agents/autoflow-implementer.md
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: run-economy placement — issue #134 (tree-quiesce, sweep ownership)
# =============================================================================
# Standing suite (verification design > Coverage lane assignment): the
# properties asserted here — the capture-point quiescence obligation's site
# set, and the whole-tree-sweep prohibition's text — are permanent structure
# of the playbooks, not this cycle's diff. Subject-named per
# docs/autoflow-guide.md:475 ("a standing test is subject-named").
#
# quiesce-rule-placed (verification design AC table): the required site set
# is DERIVED, not enumerated, from the current tree at test-run time — a
# numbered step inside a fenced phase block of docs/autoflow-guide.md whose
# JOINED step body (not line-scoped: the token wraps across a line at GREEN
# step 5) matches `tree-identity[[:space:]]+predicate` OR `run-suites\.sh`.
# This is what lets the leg fail when a LATER cycle adds a capture-point site
# without the quiescence reference, rather than asserting a frozen list.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GUIDE="$PROJECT_ROOT/docs/autoflow-guide.md"
TEAMMATE_RULES="$PROJECT_ROOT/docs/teammate-common-rules.md"
IMPL_AGENT="$PROJECT_ROOT/.claude/agents/autoflow-implementer.md"
IMPL_AGENT_MIRROR="$PROJECT_ROOT/plugin/autoflow/agents/autoflow-implementer.md"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_true() {  # assert_true <desc> <cmd...>
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "$desc"; else fail "$desc"; fi
}

assert_false() {  # assert_false <desc> <cmd...>
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then fail "$desc (unexpectedly matched)"; else pass "$desc"; fi
}

# --- Derived site-set extraction --------------------------------------------
# Extracts every numbered step body from every TOP-LEVEL (column-0) fenced
# code block of docs/autoflow-guide.md, joining wrapped continuation lines
# into one buffer per step (captured into a variable, never piped
# grep-into-grep — docs/submodule-common-rules.md > SIGPIPE-safe rule).
# Output: one line per step, "<blockno>|<stepnum>|<joined body>".
extract_fenced_steps() {
  awk '
    /^```/ {
      infence = !infence
      if (infence) { blockno++; instep = 0; next }
      else { if (instep) { print blockno "|" stepnum "|" buf }; instep = 0; next }
    }
    infence {
      if ($0 ~ /^[0-9]+\. /) {
        if (instep) { print blockno "|" stepnum "|" buf }
        stepnum = $0; sub(/\..*/, "", stepnum)
        buf = $0
        instep = 1
      } else if (instep) {
        buf = buf " " $0
      }
    }
  ' "$GUIDE"
}

STEPS="$(extract_fenced_steps)"

# The union rule (verification design > quiesce-rule-placed): a step body
# matching either token is a required capture-point site.
DERIVED_SITES="$(printf '%s\n' "$STEPS" | grep -E '\|[^|]*(tree-identity[[:space:]]+predicate|run-suites\.sh)' || true)"
DERIVED_COUNT=$(printf '%s\n' "$DERIVED_SITES" | grep -c '.' || true)

echo "quiesce-rule-placed — the derived site set (union over pre-existing tokens)"
if [ "$DERIVED_COUNT" -eq 4 ]; then
  pass "derivation selects exactly 4 sites on the current tree (GREEN step 5, VERIFY step 1, REFINE step 2, VALIDATE step 1)"
else
  fail "derivation selected $DERIVED_COUNT site(s), expected 4 -- got: $(printf '%s' "$DERIVED_SITES" | cut -d'|' -f1,2 | tr '\n' ' ')"
fi

# Each derived site's own step body must reference the rule's single
# normative home (docs/autoflow-guide.md > VERIFY > Green-tree register >
# Capture point). The consuming steps reference it and do not restate it
# (feature design > quiesce-rule), so a stable marker for "this step names
# the quiescence obligation" is the word "quiesce" itself -- the vocabulary
# both documents use for the rule's own name (quiesce-rule,
# "## Tree Quiesce (HOLD/GO)").
if [ -n "$DERIVED_SITES" ]; then
  MISSING_REF=$(printf '%s\n' "$DERIVED_SITES" | grep -viE 'quiesc' || true)
  if [ -z "$(printf '%s' "$MISSING_REF" | tr -d '[:space:]')" ]; then
    pass "every derived site's step body references the quiescence obligation"
  else
    fail "at least one derived site's step body does not reference the quiescence obligation -- $(printf '%s' "$MISSING_REF" | cut -d'|' -f1,2 | tr '\n' ' ')"
  fi
fi

echo "quiesce-rule-placed — the normative home co-locates HOLD / GO / the capture point / the bundling clause"
# The home lives in VERIFY > Green-tree register > Capture point
# (feature design > quiesce-rule > Where it lives). Captured into a variable
# (context capture, never grep-into-grep).
CAPTURE_POINT_SECTION=$(awk '
  /^### Green-tree register/ { insec = 1; next }
  insec && /^## / { exit }
  insec { print }
' "$GUIDE")

assert_true "capture-point section names HOLD" \
  bash -c "printf '%s' \"\$1\" | grep -qE 'HOLD'" _ "$CAPTURE_POINT_SECTION"
assert_true "capture-point section names GO" \
  bash -c "printf '%s' \"\$1\" | grep -qE '\\bGO\\b'" _ "$CAPTURE_POINT_SECTION"
assert_true "capture-point section states the resuming instruction travels bundled with GO in one message" \
  bash -c "printf '%s' \"\$1\" | grep -qiE 'bundl.*(one message|GO)|GO.*one message'" _ "$CAPTURE_POINT_SECTION"
assert_true "capture-point section denies a re-entry instruction followed by a separate HOLD" \
  bash -c "printf '%s' \"\$1\" | grep -qiE 'denied|is not permitted|must not'" _ "$CAPTURE_POINT_SECTION"

echo "quiesce-rule-placed — teammate-side obligation in docs/teammate-common-rules.md"
TEAMMATE_QUIESCE_SECTION=$(awk '
  /^## Tree Quiesce/ { insec = 1; print; next }
  insec && /^## / { exit }
  insec { print }
' "$TEAMMATE_RULES")

assert_true "docs/teammate-common-rules.md carries a '## Tree Quiesce (HOLD/GO)' section" \
  bash -c "printf '%s' \"\$1\" | grep -qE '^## Tree Quiesce'" _ "$TEAMMATE_QUIESCE_SECTION"
assert_true "the section states the no-tracked-tree-write obligation on HOLD" \
  bash -c "printf '%s' \"\$1\" | grep -qiE 'no tracked-tree write|not (perform|make) (a|any) tracked-tree write'" _ "$TEAMMATE_QUIESCE_SECTION"
assert_true "the section names commit / staging / file edit as forms of the prohibited write" \
  bash -c "printf '%s' \"\$1\" | grep -qiE 'commit'" _ "$TEAMMATE_QUIESCE_SECTION"

echo "dev-sweep-prohibited-text — the whole-tree-selection prohibition names BOTH reaching routes (--all AND the bare invocation) on every surface"
# GREEN step 2's [MUST] bullet list -- block/step already extracted above.
GREEN_STEP2=$(printf '%s\n' "$STEPS" | awk -F'|' '$2==2 {print; exit}')
DISPATCH_DEV_LINE=$(grep -E '^\-[[:space:]]*\*\*Developer AI\*\*:' "$GUIDE" || true)

check_both_routes() {  # check_both_routes <desc> <text>
  local desc="$1" text="$2"
  if printf '%s' "$text" | grep -qE -- '--all' \
     && printf '%s' "$text" | grep -qiE 'bare (invocation|`bash|form)|empty delta|push event|whole-tree (run|selection)|whole tree'; then
    pass "$desc names both --all and the bare-invocation/whole-tree-selection route"
  else
    fail "$desc does not (yet) name both routes -- --all alone is evadable by an empty-delta bare invocation"
  fi
}

check_both_routes "GREEN step 2's [MUST] bullet list" "$GREEN_STEP2"
check_both_routes "DISPATCH's Developer AI line" "$DISPATCH_DEV_LINE"
check_both_routes ".claude/agents/autoflow-implementer.md" "$(cat "$IMPL_AGENT" 2>/dev/null || true)"
check_both_routes "plugin/autoflow/agents/autoflow-implementer.md" "$(cat "$IMPL_AGENT_MIRROR" 2>/dev/null || true)"

echo "dev-sweep-prohibited-text / mirror-parity — the two implementer-agent contracts are byte-identical"
if diff -q "$IMPL_AGENT" "$IMPL_AGENT_MIRROR" >/dev/null 2>&1; then
  pass "autoflow-implementer.md copies byte-identical (.claude/agents vs plugin/autoflow/agents)"
else
  fail "autoflow-implementer.md copies differ"
fi

echo "p1-reconciled — docs/gate-matching-standard.md P1 subsection names the new matching primitives"
P1_SECTION=$(awk '
  /^## Rule P1/ { insec = 1; print; next }
  insec && /^## / { exit }
  insec { print }
' "$PROJECT_ROOT/docs/gate-matching-standard.md")

assert_true "P1 section names BG_TAIL" \
  bash -c "printf '%s' \"\$1\" | grep -qE 'BG_TAIL'" _ "$P1_SECTION"
assert_true "P1 section names BG_PREFIX" \
  bash -c "printf '%s' \"\$1\" | grep -qE 'BG_PREFIX'" _ "$P1_SECTION"
assert_true "P1 section names BG_SCAN (the deny-local buffer, distinct from the shared SCAN)" \
  bash -c "printf '%s' \"\$1\" | grep -qE 'BG_SCAN'" _ "$P1_SECTION"

echo "=============================="
echo "Results: $((PASS + FAIL)) total, $PASS passed, $FAIL failed"
echo "=============================="
[[ $FAIL -eq 0 ]]
