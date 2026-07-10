#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: HANDOFF documentation backend-neutral restatement — Issue #979 (AC-8)
# =============================================================================
# Scope (.autoflow/issue-979-verification-design.md §1 AC-8, feature design
# D4/rows 14-16): neutralize SPECIFIC codex-as-sole-backend sentences at named
# anchors, while PERMITTING codex to remain named as the legitimate default,
# and PRESERVING the historical "Codex Medium" evidence citations in the
# CLAUDE.md Spawn Model revert-rule rows (dated factual records, not live-path
# prose). This is deliberately anchor-scoped, not a blanket "no Codex token"
# grep — a blanket grep would over-fire against legitimate default mentions
# (verification design §1 AC-8, explicit).
#
# RED expectation (pre-implementation, this commit): the "must become neutral"
# assertions FAIL (docs still hardwire Codex as the sole backend at these
# anchors). The "must stay as-is" historical-preservation assertions PASS
# today (guards, not RED discriminators) and must keep passing after GREEN.
#
# Cycle 2 (review-response to PR #983 Codex Medium finding — "Missing Tests":
# the guard's scan window started at "**Start confirmation.**" (autoflow-
# guide.md:635) and exited at the first "^7." line (650), so it never read
# the HANDOFF section intro (618), step-4b (631), step 6's opening paragraph
# (633), the 6.5 triage body (636-638, 642), 6.7 (645), or the final report
# line (651) — the exact blind spot the reviewer flagged.
#
# .autoflow/issue-979-verification-design.md C2-AC-1/C2-AC-2 (Test AI counter
# X-1, round-2 ACCEPT, adopted by feature design §6.1): a SECOND, WIDER window
# is added spanning the full HANDOFF live-path region ("## HANDOFF —" (616)
# through "**[MUST]** AutoFlow runs neither" (654) inclusive). Its negative is
# the COMPLETE case-sensitive class `Codex [A-Za-z]` (any capital-"Codex "+
# word) rather than a hand-enumerated 7-stem list — a stem list re-creates a
# narrower version of the same blind-spot class (a future "Codex verdict"/
# "Codex label"/"Codex approval" would pass a stem list but must fail here).
# Verified (branch HEAD): every legitimate reference inside the window is
# lowercase codex (backend name / .codex/review.md / codex-review-pr.sh /
# ~/.codex/sessions / codex_max_severity / codex exec) — the complete forbid
# touches no preserved literal. The existing narrow 635-650 window and its
# two assertions (per-backend claude + completion-marker content) are kept
# unchanged; the new wide window is additive.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
GUIDE_MD="$PROJECT_ROOT/docs/autoflow-guide.md"
DESIGN_RATIONALE_MD="$PROJECT_ROOT/docs/design-rationale.md"
REVIEWER_BACKEND_MD="$PROJECT_ROOT/docs/reviewer-backend.md"

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
echo "HANDOFF documentation backend-neutral restatement (AC-8)"
echo "=============================================="

echo "=== must become neutral (RED today) ==="

PHASE_LIST_LINE="$(grep -n '^HANDOFF ' "$CLAUDE_MD" | head -1)"
assert_true "CLAUDE.md phase-list HANDOFF row reads 'configured-reviewer review', not 'Codex review'" \
  "printf '%s' \"\$PHASE_LIST_LINE\" | grep -qi 'configured.reviewer review' && ! printf '%s' \"\$PHASE_LIST_LINE\" | grep -q 'Codex review'"

TRIAGE_ROW_LINE="$(grep -n 'HANDOFF review-triage (finding ingestion' "$CLAUDE_MD" | head -1)"
assert_true "CLAUDE.md Spawn Model 'HANDOFF review-triage' row does not hardwire 'Codex-comment ingestion'" \
  "! printf '%s' \"\$TRIAGE_ROW_LINE\" | grep -qF 'Codex-comment ingestion'"

DECISION9_BODY="$([ -f "$DESIGN_RATIONALE_MD" ] && awk '
  $0 ~ /^### Decision 9:/ { f=1; next }
  f && /^### / { f=0 }
  f && /^---/ { f=0 }
  f { print }
' "$DESIGN_RATIONALE_MD" || true)"
DECISION9_JOINED="$(printf '%s' "$DECISION9_BODY" | tr '\n' ' ')"
export DECISION9_JOINED

assert_true "design-rationale.md Decision 9 label-authority prose reads 'configured isolated reviewer subprocess' (neutral)" \
  "printf '%s' \"\$DECISION9_JOINED\" | grep -qi 'configured isolated reviewer'"
assert_true "design-rationale.md Decision 9 carries a backend-neutrality footnote/mention" \
  "printf '%s' \"\$DECISION9_JOINED\" | grep -qi 'backend'"

GUIDE_STEP6_BODY="$([ -f "$GUIDE_MD" ] && awk '
  /^   \*\*Start confirmation\.\*\*/ { f=1 }
  f { print }
  f && /^7\./ { exit }
' "$GUIDE_MD" || true)"
GUIDE_STEP6_JOINED="$(printf '%s' "$GUIDE_STEP6_BODY" | tr '\n' ' ')"
export GUIDE_STEP6_JOINED

assert_true "autoflow-guide.md step-6 Start-confirmation oracle is per-backend (names claude's synchronous-return + completion-marker path, not only codex rollout/pgrep)" \
  "printf '%s' \"\$GUIDE_STEP6_JOINED\" | grep -qi 'claude' && printf '%s' \"\$GUIDE_STEP6_JOINED\" | grep -qi 'completion marker\\|completed for PR'"

assert_true "docs/reviewer-backend.md exists (D6 — new reviewer-backend contract home)" \
  "[ -f '$REVIEWER_BACKEND_MD' ]"
if [ -f "$REVIEWER_BACKEND_MD" ]; then
  assert_true "docs/reviewer-backend.md cites the claude isolation basis [MUST] (neutral-cwd does not load target .claude/settings.json hooks)" \
    "grep -qi 'setting-sources\\|settings-discovery\\|neutral.cwd' '$REVIEWER_BACKEND_MD' && grep -qi 'MUST' '$REVIEWER_BACKEND_MD'"
else
  echo "  SKIP: docs/reviewer-backend.md claude-isolation-basis citation (file absent pre-impl)"
  TESTS=$((TESTS + 1))
fi

echo ""
echo "=== must stay as-is (guard, not a RED discriminator) ==="

REVERT_ROW_LINE="$(grep -n 'issue #287 cycle 1: sonnet PASS avg 8.9 contradicted by a same-cycle Codex Medium finding' "$CLAUDE_MD" | head -1)"
assert_true "CLAUDE.md Spawn Model revert-rule row PRESERVES the historical 'Codex Medium' evidence citation (dated factual record, not live-path prose)" \
  "[ -n \"\$REVERT_ROW_LINE\" ]"

assert_true "autoflow-guide.md step 6 still permits 'codex' as the named default backend (no over-neutralization)" \
  "printf '%s' \"\$GUIDE_STEP6_JOINED\" | grep -qi 'codex'"

echo ""
echo "=== cycle 2: widened HANDOFF live-path window (was the blind spot) ==="

# Verification design C2-AC-1/C2-AC-2 (Test AI counter X-1, round-2 ACCEPT):
# second, wider window over the FULL HANDOFF live-path region — start
# "## HANDOFF —" (616), through and including "**[MUST]** AutoFlow runs
# neither" (654) — covers 618, 631, 633, 636-638, 642, 645, 651 (the
# reviewer's Missing-Tests blind spot); historical 521/525/542 precede 616
# and are naturally excluded.
HANDOFF_WIDE_BODY="$([ -f "$GUIDE_MD" ] && awk '
  /^## HANDOFF —/ { f=1 }
  f { print }
  f && /^\*\*\[MUST\]\*\* AutoFlow runs neither/ { exit }
' "$GUIDE_MD" || true)"
HANDOFF_WIDE_JOINED="$(printf '%s' "$HANDOFF_WIDE_BODY" | tr '\n' ' ')"
export HANDOFF_WIDE_JOINED

assert_true "autoflow-guide.md widened HANDOFF window (616-654) does NOT contain any capital-'Codex <word>' live-path phrase (complete class, not a hand-enumerated stem list — RED today at 618/631/633/636/637/638/642/645/651)" \
  "! printf '%s' \"\$HANDOFF_WIDE_JOINED\" | grep -q 'Codex [A-Za-z]'"

assert_true "autoflow-guide.md widened HANDOFF window has landed neutral vocabulary ('configured-reviewer'/'reviewer review'/'reviewer comment'/'reviewer re-review'/'reviewer session'), proving text was replaced, not merely deleted" \
  "printf '%s' \"\$HANDOFF_WIDE_JOINED\" | grep -qiE 'configured.reviewer|reviewer (review|comment|re-review|session)'"

assert_true "autoflow-guide.md widened HANDOFF window still permits lowercase 'codex' as the named default backend (no over-neutralization)" \
  "printf '%s' \"\$HANDOFF_WIDE_JOINED\" | grep -qi 'codex'"

echo ""
echo "=== cycle 2: CLAUDE.md HANDOFF descriptions (9/12/82/205/283/311) ==="

# X-2 (Test AI, round-2 ACCEPT): whole-file substring negative is sound ONLY
# while no legitimate dated citation carries the exact substring "Codex
# review" (F5-verified: rows 65/71 say "Codex Medium", not "Codex review").
# If a future CLAUDE.md edit adds a legitimate dated "Codex review" citation,
# convert this to a windowed assertion instead of letting it silently
# false-fire.
assert_true "CLAUDE.md contains no live-path 'Codex review' phrase (fires on 9/12/82/205/283/311 today; F5 dependency — see X-2 comment above)" \
  "! grep -q 'Codex review' \"$CLAUDE_MD\""

echo ""
echo "=== cycle 2: design-rationale.md Decision 9 title + body ==="

assert_true "design-rationale.md Decision 9 title does not name 'Codex' (backend-neutral title)" \
  "grep '^### Decision 9:' \"$DESIGN_RATIONALE_MD\" | grep -qv 'Codex'"

assert_true "design-rationale.md Decision 9 Problem/Decision body does not match 'Codex (review|verdict|comment)' or 're-Codex' (RED today at 180/182)" \
  "! printf '%s' \"\$DECISION9_JOINED\" | grep -qE 'Codex (review|verdict|comment)|re-Codex'"

echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
