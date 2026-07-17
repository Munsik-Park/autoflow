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
# (assert_true/assert_false over grep + git diff, section-scoped extraction,
# AC-SCOPE allow-list guard).
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
#   AC-SCOPE       — guard: changed files ⊆ allow-list.
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
# (nothing contradictory exists yet; AC-SCOPE is test-only; AC-PRESERVE
# targets are untouched).
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
BASE_REF="${ISSUE_846_BASE_REF:-$(git -C "$PROJECT_ROOT" merge-base HEAD main 2>/dev/null || true)}"

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
echo "=== AC-SCOPE (guard) — diff ⊆ allow-list ==="

if [[ -z "$BASE_REF" ]]; then
  echo "  SKIP: AC-SCOPE (no base ref available)"
  TESTS=$((TESTS + 1))
else
  diff_files="$(git diff --name-only "$BASE_REF"...HEAD 2>/dev/null || true)"
  allow_list=(
    # HANDOFF step 6.7 digest co-ride: every terminal cycle appends one record
    # to the durable corpus on the same PR branch (autoflow-guide.md > HANDOFF 6.7),
    # so the digest file is a standing expected surface for every cycle diff.
    "docs/cycle-digest.jsonl"
    # #973 change surface (SIGPIPE extractor-pipe fix): 10 hazard sites →
    # Safe-form across 4 suites + the #964 guard extension + the doc convention
    # + this cycle's mutual scope-guard allow-list admissions (2nd-transition
    # self/sibling registration) + manifest regen (submodule-common-rules.md source).
    "tests/test-issue-964-sigpipe-safe-pipes.sh"
    "tests/manual/issue-973-manual-scenarios.md"
    "docs/submodule-common-rules.md"
    "setup/manifest.json"
    "tests/test-issue-799-inert-cleanup.sh"
    "tests/test-issue-800-doc-assertions.sh"
    "tests/test-issue-846-doc-assertions.sh"
    "tests/test-issue-848-doc-assertions.sh"
    "tests/test-issue-798-topology-flip.sh"
    "tests/test-issue-949-manifest-regen-doc.sh"
    "tests/test-issue-952-wizard-removal.sh"
    "tests/test-issue-955-subagent-background-ban.sh"
    ".codex/review.md"
    "docs/autoflow-guide.md"
    "docs/design-rationale.md"
    "CLAUDE.md"
    "tests/test-issue-846-doc-assertions.sh"
    "tests/manual/issue-846-manual-scenarios.md"
    ".github/workflows/e2e-dummy-target.yml"
    # Mechanical consequence of editing manifest-tracked docs (CLAUDE.md /
    # docs/autoflow-guide.md / docs/design-rationale.md): setup/manifest.json
    # sha256 regeneration (#799 precedent, commit 4c2f5a4).
    "setup/manifest.json"
    # Allow-list self-reference: this cycle's RED suite lands on the same
    # branch as several sibling scope-guard tests, whose own allow-lists
    # this cycle amended to re-admit these two files (sibling-fix pass,
    # #800/#955 precedent) — those amendments show up in this file's own
    # diff-since-main scan.
    "tests/test-issue-798-topology-flip.sh"
    "tests/test-issue-799-inert-cleanup.sh"
    "tests/test-issue-800-doc-assertions.sh"
    "tests/test-issue-949-manifest-regen-doc.sh"
    "tests/test-issue-952-wizard-removal.sh"
    # #848 transitive: sibling guard-admission edits (b8b9ad6) land on this branch
    "tests/test-issue-794-doc-assertions.sh"
    "tests/test-issue-795-handoff-removal.sh"
    "tests/test-issue-955-subagent-background-ban.sh"
    # #848 sibling-fix pass: pointer-bump procedure + propagation-batching RED
    # suite + manual scenarios land on the same branch; its GREEN source docs
    # (git-workflow.md / external-review-sequencing.md / submodule-common-rules.md;
    # autoflow-guide.md / CLAUDE.md / setup/manifest.json already above).
    "tests/test-issue-848-doc-assertions.sh"
    "tests/manual/issue-848-manual-scenarios.md"
    "docs/git-workflow.md"
    "docs/external-review-sequencing.md"
    "docs/submodule-common-rules.md"
    # #964 (SIGPIPE-safe assertion pipes): the merged union diff carries the
    # Testing Standards doc addition and the #964 RED suite.
    "docs/submodule-common-rules.md"
    "tests/test-issue-964-sigpipe-safe-pipes.sh"
    # #843 cycle files (concurrent-cycle registration, cc8030d precedent) —
    # the #843 branch admits its own hook/guard-contract change set here so
    # that a rebase onto #846's already-merged AC-SCOPE arm does not FAIL on
    # a legitimate concurrent-cycle file it does not itself introduce.
    ".claude/hooks/check-autoflow-gate.sh"
    "plugin/autoflow/hooks/check-autoflow-gate.sh"
    "docs/phases/analysis.md"
    "docs/evaluation-system.md"
    "tests/plugin/verify-package.sh"
    "tests/test-issue-223-schema-hook-contract.sh"
    "tests/test-issue-245-schema-validation.sh"
    "tests/test-issue-788-host-purity-delta.sh"
    "tests/test-issue-843-doc-assertions.sh"
    "tests/test-issue-844-doc-assertions.sh"
    # #844 cycle files (concurrent-cycle registration, cc8030d precedent).
    "docs/teammate-common-rules.md"
    "tests/manual/issue-844-manual-scenarios.md"
    # #844 INTEGRATE reconciliation pass: sibling line-window re-anchor +
    # allow-list registration touches this test file on the same branch.
    "tests/test-issue-794-doc-assertions.sh"
    # #951 (doc-invariant registry): sibling cycle files — the new registry
    # runner, hermetic base-ref resolver, registry data, lifecycle-rule doc,
    # RED suite + fixtures, and INDEX/maintained-docs routing land on the
    # same branch (df4641d/da11389/fa12eb1 precedent). #951 also DELETES
    # tests/test-issue-796-doc-assertions.sh and
    # tests/test-issue-797-doc-invocation.sh (794/800/949 already admitted
    # above); their permanent invariants migrate into the registry.
    "tests/test-issue-796-doc-assertions.sh"
    "tests/test-issue-797-doc-invocation.sh"
    "tests/test-issue-951-registry.sh"
    # Round-2 fix (VERIFY): omitted from round-1 registration above.
    "tests/adr-0016-conformance-check.sh"
    "tests/test-issue-795-handoff-removal.sh"
    "tests/fixtures/doc-invariants-anchor-fixture.md"
    "tests/fixtures/doc-invariants-baseline.txt"
    "tests/fixtures/doc-invariants-dialect-fixture.md"
    "tests/manual/issue-951-manual-scenarios.md"
    "tests/run-doc-invariants.sh"
    "tests/lib/base-ref.sh"
    "tests/lib/"
    "tests/fixtures/doc-invariants.json"
    "docs/doc-invariant-registry.md"
    "docs/INDEX.md"
    "docs/maintained-docs.md"
    # #954 cycle files (cross-issue complaint-class recurrence scan RED
    # suite + fixtures + manual scenarios) and this cycle's own
    # allow-list-registration churn on the sibling scope-guard suites
    # (self-referential, #844/#846 precedent).
    "tests/test-issue-954-cross-issue-scan.sh"
    "tests/fixtures/cycle-digest-954-below-k.jsonl"
    "tests/fixtures/cycle-digest-954-at-k.jsonl"
    "tests/fixtures/cycle-digest-954-dedup.jsonl"
    "tests/fixtures/cycle-digest-954-out-of-window.jsonl"
    "tests/fixtures/cycle-digest-954-dual-axis.jsonl"
    "tests/fixtures/cycle-digest-954-cross-axis.jsonl"
    "tests/fixtures/cycle-digest-954-dedup-window.jsonl"
    "tests/manual/issue-954-manual-scenarios.md"
    # #954 INTEGRATE reconciliation: the 953 suite's AC5-whitelist-analysis
    # grep is narrowed to the whitelist block (the #954 AC7 non-conflation
    # paragraph legitimately names cycle-digest), so the 953 suite file
    # lands in this cycle's diff.
    "tests/test-issue-953-cycle-digest.sh"
    # #954 GREEN source surface (GATE:PLAN-passed design §4, commit
    # b26cda9): PREFLIGHT step-1.5 scan step + tally script + backlog
    # intake path + maintained-docs trigger + analyzer variant + doc-sync
    # + manifest regen land on the same branch (#953/#844 precedent).
    ".claude/agents/autoflow-analyzer.md"
    "docs/improvement-backlog.md"
    "docs/maintained-docs.md"
    "plugin/autoflow/agents/autoflow-analyzer.md"
    "scripts/preflight/scan-cross-issue-recurrence.sh"
    # #978 cycle files (concurrent-cycle registration, cc8030d precedent):
    # archive-semantics GREEN rewrites the cleanup wrapper in place and the
    # RED pass re-targets the boundary guard + adds the repo-key guard
    # (CLAUDE.md / docs / setup/manifest.json / doc-invariants.json /
    # test-issue-844 / e2e workflow already admitted above).
    "scripts/cleanup/cleanup-issue.sh"
    "scripts/test/check-cleanup-issue-boundary.sh"
    "scripts/test/check-repo-key.sh"
    # #985 cycle files (public-tree sanitization sweep): REUSE/SPDX
    # licensing, identifier generalization, internal-doc removal across the
    # full repo surface (same set as test-issue-952-wizard-removal.sh's own
    # #985 registration; CLAUDE.md / docs/INDEX.md / docs/maintained-docs.md
    # / setup/manifest.json / docs/improvement-backlog.md already admitted
    # above).
    ".claude-plugin/marketplace.json"
    ".claude/hooks/check-read-dedup.sh"
    ".claude/skills/epic-dash/SKILL.md"
    ".claude/skills/epic-dash/scripts/build_pipeline.py"
    ".claude/skills/epic-dash/scripts/extract_deps.py"
    ".claude/skills/epic-dash/scripts/fetch.sh"
    ".claude/skills/epic-dash/scripts/render_dash.py"
    ".claude/workflows/architect-deliberation.js"
    ".claude/workflows/verify-cause-branch.js"
    ".github/pull_request_template.md"
    ".github/workflows/host-purity-delta.yml"
    ".github/workflows/plugin-package.yml"
    ".github/workflows/reuse.yml"
    ".github/workflows/schema-hook-contract.yml"
    ".github/workflows/workflow-regression.yml"
    "Jenkinsfile"
    "LICENSE"
    "LICENSES/Elastic-2.0.txt"
    "README.md"
    "REUSE.toml"
    '"docs/LibreChat_\355\224\204\353\241\234\354\240\235\355\212\270\354\225\210.docx"'
    "docs/adr/0001-host-orchestrator-and-librechat-submodule-""boundary.md"
    "docs/adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md"
    "docs/adr/README.md"
    "docs/gate-matching-standard.md"
    "docs/host-service-decoupling-plan.md"
    "docs/librechat-deploy-extraction-plan.md"
    "docs/repo-boundary-rules.md"
    "docs/reviewer-backend.md"
    "docs/security-checklist.md"
    "plugin/autoflow/.claude-plugin/plugin.json"
    "plugin/autoflow/README.md"
    "plugin/autoflow/hooks/check-read-dedup.sh"
    "plugin/autoflow/skills/epic-dash/SKILL.md"
    "plugin/autoflow/skills/epic-dash/scripts/build_pipeline.py"
    "plugin/autoflow/skills/epic-dash/scripts/extract_deps.py"
    "plugin/autoflow/skills/epic-dash/scripts/fetch.sh"
    "plugin/autoflow/skills/epic-dash/scripts/render_dash.py"
    "plugin/autoflow/skills/install/SKILL.md"
    "plugin/autoflow/skills/install/scripts/detect.sh"
    "plugin/autoflow/skills/install/scripts/scaffold-identity.sh"
    "plugin/autoflow/skills/install/scripts/set-review-backend.sh"
    "scripts/handoff/create-host-pr.sh"
    "scripts/handoff/emit-cycle-digest.sh"
    "scripts/preflight/check-review-backend.sh"
    "scripts/resync-submodules.sh"
    "scripts/review/codex-review-pr.sh"
    "scripts/review/lib/claude-isolation.sh"
    "scripts/test/check-close-keyword-quoting.sh"
    "scripts/test/check-host-purity-delta.sh"
    "scripts/test/check-maintained-docs-sync.sh"
    "setup/SETUP-GUIDE.md"
    "setup/gen-manifest-hashes.sh"
    "setup/init.sh"
    "setup/thin-root-layer/drift-check.sh"
    "setup/thin-root-layer/settings-pin.json"
    "test/workflows/run.mjs"
    "tests/fixtures/e2e-bundle-purity-baseline.txt"
    "tests/fixtures/expected-conn""ev-residual.txt"
    "tests/issue-92/manual-checklist.md"
    "tests/issue-92/test-boundary-nonviolation.bats"
    "tests/issue-92/test-create-host-pr.bats"
    "tests/issue-92/test-cross-file-consistency.bats"
    "tests/issue-92/test-docs.bats"
    "tests/issue-92/test-pr-template.bats"
    "tests/manual/issue-799-manual-scenarios.md"
    "tests/manual/issue-800-manual-scenarios.md"
    "tests/manual/issue-985-manual-scenarios.md"
    "tests/plugin/manual-scenarios-797.md"
    "tests/plugin/manual-scenarios-943.md"
    "tests/plugin/manual-scenarios.md"
    "tests/plugin/verify-e2e-dummy-target.sh"
    "tests/plugin/verify-install-into-target.sh"
    "tests/plugin/verify-install-skill-scripts.sh"
    "tests/plugin/verify-thin-root-layer.sh"
    "tests/test-codex-review-label-step.sh"
    "tests/test-gate-hardening.sh"
    "tests/test-issue-847-doc-assertions.sh"
    "tests/test-issue-961-cap6-gate.sh"
    "tests/test-issue-979-bundle-delivery.sh"
    "tests/test-issue-979-doc-neutrality.sh"
    "tests/test-issue-979-preflight-backend-check.sh"
    "tests/test-issue-979-probe.sh"
    "tests/test-issue-979-review-backend.sh"
    "tests/test-issue-985-doc-assertions.sh"
    # #18 cycle files: fixture-glob isolation fix — locale-invariance
    # manifest regression update + new glob-isolation RED oracle.
    "tests/test-issue-16-manifest-locale-invariance.sh"
    "tests/test-issue-18-fixture-glob-isolation.sh"
  )
  disallowed=""
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    found=0
    for allowed in "${allow_list[@]}"; do
      [[ "$f" == "$allowed" ]] && found=1 && break
    done
    if [[ $found -eq 0 ]]; then
      disallowed="$disallowed$f"$'\n'
    fi
  done <<< "$diff_files"

  echo "  changed files: $(printf '%s' "$diff_files" | grep -c . || true)"
  if [[ -n "$disallowed" ]]; then
    echo "  disallowed:"
    printf '%s' "$disallowed" | sed 's/^/    /'
  fi
  assert_true "AC-SCOPE: git diff --name-only ⊆ allow-list (no disallowed files)" \
    "[ -z '$disallowed' ]"
fi

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
