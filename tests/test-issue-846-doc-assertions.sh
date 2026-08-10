#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: review-triage hardening — label-clear fallback + 7-attempt cap reset
#       semantics + durable record — Issue #846 ([fix · #842-S4])
# =============================================================================
# Tier-1 scripted assertion suite per verification design
# (.autoflow/issue-846-verification-design.md §4/§5). Docs-only change (no
# jest, no npm) — mirrors tests/test-codex-review-label-step.sh (grep the
# real file, not a copy) and tests/test-issue-800-doc-assertions.sh
# (assert_true/assert_false over grep + git diff, section-scoped extraction).
#
# Resolution set {R1, R3, R4} → AC1/AC2/AC3 (verification design §1):
#
#   AC1-FALLBACK   — RED discriminator: .codex/review.md label-removal bullet
#                    carries the `gh issue edit <PR_NUMBER> --remove-label
#                    blocked-by-review` fallback.
#   AC1-SUBREPO    — RED discriminator: same bullet notes `--repo` for
#                    sub-repo PRs.
#   AC1-VERIFY     — RED discriminator: same bullet contains a
#                    `gh pr view <PR_NUMBER> --json labels` verification,
#                    ordered before the success/failure report.
#   AC1-ACTOR      — guard (PASS pre+post): no `--remove-label
#                    blocked-by-review` command appears in
#                    docs/autoflow-guide.md orchestrator-side text
#                    (hook-deny tension guard, feature design §2.1 [MUST]).
#   AC2-GUIDE      — RED discriminator: docs/autoflow-guide.md cap sentence
#                    carries the verbatim canonical window phrase
#                    (feature design §2.2).
#   AC2-RATIONALE  — RED discriminator: docs/design-rationale.md Decision 9
#                    carries the same verbatim substrings (dual-file AND).
#   AC2-NOCONTRA   — guard (PASS pre+post): no bare count-predicate mention
#                    coexists with the window phrase in the same file
#                    (anti-append-beside guard).
#   AC2-NOLABELCLEAR — guard (PASS pre+post): no sentence names a
#                    label-clear as a cap-window reset trigger.
#   AC3-DURABLE    — RED discriminator: docs/autoflow-guide.md step 6.5
#                    requires a durable host-PR record naming both cap-fire
#                    and user re-entry.
#   AC3-GITHUBSIDE — guard (PASS pre+post): the durable-record clause points
#                    at a GitHub-side host PR, not at `.autoflow/*`/ledger.
#   CLAUDEMD-NOCONTRA — guard: CLAUDE.md carries no cap semantics
#                    contradicting the new window.
#   AC-PRESERVE    — guard (PASS pre+post): existing label-removal-failure
#                    clause + hook-deny language survive.
#   AC-CI-REGISTER — guard: this suite is wired into
#                    .github/workflows/e2e-dummy-target.yml (both `paths:`
#                    trigger blocks + a `run:` step), #798/#799/#800
#                    precedent.
#
# Not in this file (verification design §5, Tier-2/Tier-3 — delegated to
# tests/manual/issue-846-manual-scenarios.md):
#   AC1 ordering/procedural correctness semantic judgment      — Tier 2
#   AC2 reset-at-re-entry coherence judgment                   — Tier 2
#   AC3 placement/ledger-cleanup-survival judgment              — Tier 2
#   AC1 live `gh issue edit --remove-label` efficacy            — Tier 3 (already evidenced, PR #194)
#   AC3 live posted durable comment on a real cap-fire          — Tier 3 (future review-response cycle)
#
# RED expectation (pre-edit, this commit): AC1-FALLBACK, AC1-SUBREPO,
# AC1-VERIFY, AC2-GUIDE, AC2-RATIONALE, AC3-DURABLE FAIL (fallback/verify
# tokens absent from .codex/review.md, window phrase absent from both docs,
# durable-record clause absent from step 6.5). All guards PASS pre-edit
# (nothing contradictory exists yet; AC-PRESERVE targets are untouched).
#
# Harness convention: set -uo pipefail, assert_true/assert_false, canonical
# `Results: P/T passed, F failed` line, exit 1 iff F>0.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CODEX_REVIEW="$PROJECT_ROOT/.codex/review.md"
AUTOFLOW_GUIDE="$PROJECT_ROOT/docs/autoflow-guide.md"
DESIGN_RATIONALE="$PROJECT_ROOT/docs/design-rationale.md"
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
CI_WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"

# Base ref for scope-containment diff guard (precedent: #797/#798/#799/#800).

PASS=0; FAIL=0; TESTS=0

# ---------------------------------------------------------------------------
# Helpers (assert_* pattern per tests/test-issue-800-doc-assertions.sh)
# ---------------------------------------------------------------------------

assert_true() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if (cd "$PROJECT_ROOT" && eval "$condition"); then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

assert_false() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if (cd "$PROJECT_ROOT" && eval "$condition"); then
    echo "  FAIL: $desc (forbidden condition held)"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

# ---------------------------------------------------------------------------
# Section extractors — scope discriminator greps to the exact target section
# (verification design §0 line-number policy: anchor on content within its
# named section, never an absolute line number — this issue's own source
# citations had line-drift per DIAGNOSE Phase 3/B).
# ---------------------------------------------------------------------------

# The label-removal bullet in .codex/review.md is the single line/paragraph
# starting "After posting the PR review comment, remove the
# `blocked-by-review` label ...". Extract from that anchor to the next
# blank-line-delimited paragraph boundary (the file uses one bullet per
# paragraph, no sub-headings for this contract).
label_removal_bullet() {
  awk '/^- After posting the PR review comment, remove the `blocked-by-review` label/{f=1} f{print} f && /^$/{exit}' "$CODEX_REVIEW"
}

# The step 6.5 review-triage block in autoflow-guide.md: from the
# "6.5. Review triage" numbered item to the closing fence of the numbered
# HANDOFF procedure code block. Stopping at the fence (not at the next
# "### " heading) excludes unrelated prose after the fence that also
# happens to say "host PR" (e.g. the Closes-#N [MUST] bullet), which would
# otherwise make the AC3-DURABLE discriminator vacuously true pre-edit.
step_65_section() {
  awk '
    /^6\.5\. Review triage/ {f=1}
    f && /^```$/ {exit}
    f {print}
  ' "$AUTOFLOW_GUIDE"
}

# Decision 9 block in design-rationale.md: from its "### Decision 9:" heading
# to the next "---" horizontal rule.
decision_9_section() {
  awk '/^### Decision 9:/{f=1} f{print} f && /^---$/{exit}' "$DESIGN_RATIONALE"
}

# CLAUDE.md Regressions line (Flow Control section) — the sentence carrying
# the review-response cap wording.
claude_regressions_line() {
  grep -F 'Codex review auto-resolution (Medium+ found at HANDOFF)' "$CLAUDE_MD"
}

# Canonical window-phrase substrings (feature design §2.2, verbatim,
# character-for-character reuse required in both docs).
WINDOW_SUB_A='review-autofix`-marked ledger entries since the last user re-entry decision'
WINDOW_SUB_B='reset by that decision'

# =============================================================================
echo "=== AC1-FALLBACK/AC1-SUBREPO/AC1-VERIFY (RED discriminators) — .codex/review.md label-removal bullet ==="

assert_true "AC1-FALLBACK: label-removal bullet carries the 'gh issue edit <PR_NUMBER> --remove-label blocked-by-review' fallback" \
  "ctx=\$(label_removal_bullet); printf '%s\n' \"\$ctx\" | grep -qF 'gh issue edit <PR_NUMBER> --remove-label blocked-by-review'"
assert_true "AC1-SUBREPO: label-removal bullet notes --repo for sub-repo PRs" \
  "ctx=\$(label_removal_bullet); printf '%s\n' \"\$ctx\" | grep -qF -- '--repo'"
assert_true "AC1-VERIFY: label-removal bullet requires 'gh pr view <PR_NUMBER> --json labels' verification before reporting" \
  "ctx=\$(label_removal_bullet); printf '%s\n' \"\$ctx\" | grep -qF 'gh pr view <PR_NUMBER> --json labels'"

# =============================================================================
echo ""
echo "=== AC1-ACTOR (guard, PASS pre+post) — no orchestrator-side --remove-label in autoflow-guide.md ==="

assert_false "AC1-ACTOR: docs/autoflow-guide.md does not carry a --remove-label blocked-by-review command" \
  "grep -qF -- '--remove-label blocked-by-review' '$AUTOFLOW_GUIDE'"

# =============================================================================
echo ""
echo "=== AC2-GUIDE/AC2-RATIONALE (RED discriminators) — verbatim canonical window phrase, dual-file AND ==="

assert_true "AC2-GUIDE: docs/autoflow-guide.md step 6.5 carries the verbatim window-phrase substring A" \
  "ctx=\$(step_65_section); printf '%s\n' \"\$ctx\" | grep -qF \"\$WINDOW_SUB_A\""
assert_true "AC2-GUIDE: docs/autoflow-guide.md step 6.5 carries the verbatim window-phrase substring B" \
  "ctx=\$(step_65_section); printf '%s\n' \"\$ctx\" | grep -qF \"\$WINDOW_SUB_B\""
assert_true "AC2-RATIONALE: docs/design-rationale.md Decision 9 carries the verbatim window-phrase substring A" \
  "ctx=\$(decision_9_section); printf '%s\n' \"\$ctx\" | grep -qF \"\$WINDOW_SUB_A\""
assert_true "AC2-RATIONALE: docs/design-rationale.md Decision 9 carries the verbatim window-phrase substring B" \
  "ctx=\$(decision_9_section); printf '%s\n' \"\$ctx\" | grep -qF \"\$WINDOW_SUB_B\""

# =============================================================================
echo ""
echo "=== AC2-NOCONTRA (guard, PASS pre+post) — bare monotone count not left standing beside the window phrase ==="
# PASS pre-edit is expected (window phrase absent ⇒ no coexistence to
# violate — a genuine PASS-pre+post guard, not a discriminator per
# verification design §4).

assert_false "AC2-NOCONTRA (autoflow-guide.md): bare 'Count this issue's review-autofix-marked ledger entries' does not coexist with the window phrase" \
  "ctx=\$(step_65_section); printf '%s\n' \"\$ctx\" | grep -qF 'Count this issue'\''s' && printf '%s\n' \"\$ctx\" | grep -qF \"\$WINDOW_SUB_A\""
assert_false "AC2-NOCONTRA (design-rationale.md): bare '(counted via review-autofix-marked ledger entries)' does not coexist with the window phrase" \
  "ctx=\$(decision_9_section); printf '%s\n' \"\$ctx\" | grep -qF '(counted via \`review-autofix\`-marked ledger entries)' && printf '%s\n' \"\$ctx\" | grep -qF \"\$WINDOW_SUB_A\""

# =============================================================================
echo ""
echo "=== AC2-NOLABELCLEAR (guard, PASS pre+post) — sole reset anchor is user re-entry, never label-clear ==="

assert_false "AC2-NOLABELCLEAR (autoflow-guide.md): no sentence names a label-clear as the cap-window reset trigger" \
  "ctx=\$(step_65_section); printf '%s\n' \"\$ctx\" | grep -qiE 'label.?clear[^.]*reset|reset[^.]*label.?clear'"
assert_false "AC2-NOLABELCLEAR (design-rationale.md): no sentence names a label-clear as the cap-window reset trigger" \
  "ctx=\$(decision_9_section); printf '%s\n' \"\$ctx\" | grep -qiE 'label.?clear[^.]*reset|reset[^.]*label.?clear'"

# =============================================================================
echo ""
echo "=== AC3-DURABLE (RED discriminator) — durable host-PR record on cap-fire + user re-entry ==="

assert_true "AC3-DURABLE: step 6.5 requires a durable record naming the host PR" \
  "ctx=\$(step_65_section); printf '%s\n' \"\$ctx\" | grep -qiF 'host PR'"
assert_true "AC3-DURABLE: step 6.5 durable-record clause covers the cap-fire trigger" \
  "ctx=\$(step_65_section); printf '%s\n' \"\$ctx\" | grep -qiE 'cap (fired|fires|firing)'"
assert_true "AC3-DURABLE: step 6.5 durable-record clause covers the user re-entry trigger" \
  "ctx=\$(step_65_section); printf '%s\n' \"\$ctx\" | grep -qiF 're-entry decision'"

# =============================================================================
echo ""
echo "=== AC3-GITHUBSIDE (guard) — durable record targets GitHub-side host PR, not the ledger ==="

if ctx=$(step_65_section); printf '%s\n' "$ctx" | grep -qiF 'host PR'; then
  assert_false "AC3-GITHUBSIDE: the durable-record clause does not point at .autoflow/*/the ledger as the record location" \
    "ctx=\$(step_65_section); ctx2=\$(printf '%s\n' \"\$ctx\" | grep -A3 -iF 'host PR'); printf '%s\n' \"\$ctx2\" | grep -qiE '\\.autoflow|the ledger'"
else
  echo "  SKIP: AC3-GITHUBSIDE (no 'host PR' durable-record clause yet — covered by AC3-DURABLE RED)"
  TESTS=$((TESTS + 1))
fi

# =============================================================================
echo ""
echo "=== CLAUDEMD-NOCONTRA (guard) — CLAUDE.md cap wording not contradicting the new window ==="

assert_false "CLAUDEMD-NOCONTRA: CLAUDE.md Regressions line does not name label-clear as a reset trigger" \
  "ctx=\$(claude_regressions_line); printf '%s\n' \"\$ctx\" | grep -qiE 'label.?clear[^.]*reset|reset[^.]*label.?clear'"

# =============================================================================
echo ""
echo "=== AC-PRESERVE (guard, PASS pre+post) — existing label-removal-failure clause + hook-deny language survive ==="

assert_true "AC-PRESERVE: .codex/review.md still requires reporting failure clearly if label removal fails" \
  "ctx=\$(label_removal_bullet); printf '%s\n' \"\$ctx\" | grep -qF 'If label removal fails, report the failure clearly'"
assert_true "AC-PRESERVE: docs/autoflow-guide.md/design-rationale.md still state the orchestrator never owns/clears the label" \
  "grep -qiF 'orchestrator never owns the label' '$DESIGN_RATIONALE'"


# =============================================================================
echo ""
echo "=== AC-CI-REGISTER (guard) — suite wired into e2e-dummy-target.yml ==="

if [[ -f "$CI_WORKFLOW" ]]; then
  assert_true "AC-CI-a: e2e-dummy-target.yml references test-issue-846-doc-assertions.sh" \
    "grep -q 'test-issue-846-doc-assertions' '$CI_WORKFLOW'"
  assert_true "AC-CI-b: reference appears in a 'paths:' trigger block" \
    "ctx=\$(grep -B30 'test-issue-846-doc-assertions' '$CI_WORKFLOW'); printf '%s\n' \"\$ctx\" | grep -q '^ *paths:'"
  assert_true "AC-CI-c: reference appears in a 'run:' step" \
    "ctx=\$(grep -A2 'name:.*#846\\|test-issue-846-doc-assertions' '$CI_WORKFLOW'); printf '%s\n' \"\$ctx\" | grep -q 'run: bash tests/test-issue-846-doc-assertions.sh'"
else
  assert_true "AC-CI-a: $CI_WORKFLOW exists" "false"
  echo "  SKIP: AC-CI-b/c (workflow file missing)"
  TESTS=$((TESTS + 2))
fi

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
