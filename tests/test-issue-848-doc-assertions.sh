#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: pointer-bump procedure + nested-fix propagation batching
#       (subrepo-gate ADR follow-up) — Issue #848 ([fix · #842-S6])
# =============================================================================
# Tier-1 scripted assertion suite per verification design
# (.autoflow/issue-848-verification-design.md §1/§2). Docs-only change (no
# jest, no npm) — mirrors tests/test-issue-846-doc-assertions.sh /
# tests/test-issue-800-doc-assertions.sh conventions: assert_true/assert_false
# over grep + git diff, section-scoped extraction (no line-number anchors —
# this issue's own source citations had line-drift per DIAGNOSE Phase 3/B),
# canonical `Results: P/T passed, F failed` line, exit 1 iff F>0.
#
# AC → discriminator/guard map (verification design §1):
#
#   AC1 — pointer-bump commit procedure (actor/trigger/format) canonical:
#     AC1-DELIVER-MARKER   RED — DELIVER multi-repo list promoted to a
#                           `*Secondary (multi-repo):*` marker bullet.
#     AC1-DELIVER-ACTOR    RED — that marker block names `orchestrator`.
#     AC1-DELIVER-GITLINK  RED — that marker block names the `services`
#                           gitlink/pointer target.
#     AC1-DELIVER-FORWARDREF RED — that marker block forward-refs HANDOFF
#                           step 4b for the commit format (single-source —
#                           format itself lives only in HANDOFF step 4b).
#     AC1-HANDOFF-STEP     RED — HANDOFF step 4b (host PR) carries the SOLE
#                           commit-format snippet (`git add services` +
#                           `chore(#N): bump services pointer to <short-sha>`).
#     AC1-OWNERSHIP-ROW    RED — CLAUDE.md Commit Ownership table gets a
#                           pointer-bump row, committer = Orchestrator.
#     AC1-XREF             RED — submodule-common-rules.md gains a
#                           cross-ref note reconciling "each developer
#                           commits only the submodule pointer" with the
#                           orchestrator actor.
#     AC1-NO-HOSTONLY-BLEED  guard (PASS pre+post) — the DELIVER host-only
#                           (default) paragraph never gains `git add services`.
#     AC1-XREF-NOCONTRA    guard (PASS pre+post) — the pre-existing
#                           "only the submodule pointer" sentence survives.
#
#   AC2 — review-response re-bump [MUST] + git ls-tree verification:
#     AC2-MUST              RED — HANDOFF step 3 block gets [MUST] +
#                           re-bump + `git ls-tree HEAD services` tokens.
#     AC2-SOLE-DEFENSE      RED — same block states the English sole-defense
#                           phrase ("only remaining") + a #795/ADR-0015 anchor.
#     AC2-NO-PERPUSH        guard (PASS pre+post) — step-3→step-4 marker-
#                           scoped block never mandates per-push re-bump
#                           (AC4 timing-coherence complement).
#
#   AC3 — git-workflow.md stale handoff-sequence.yml/subrepo-merged/Exit 79
#         machine-verify description correction:
#     AC3-NO-LIVE-WORKFLOW  RED — Merge Sequencing section-scope: no
#                           `handoff-sequence.yml` mention without an
#                           accompanying retirement token (#795/ADR-0015/
#                           retire), and no current-tense "machine-verifies /
#                           publishes ... status check" combined with
#                           handoff-sequence/subrepo-merged.
#     AC3-EXIT79-CTX        RED — Pointer-reconciliation section-scope: no
#                           `subrepo-merged`/`Exit 79` attribution without
#                           an accompanying retirement token.
#     AC3-RETIRE-ALIGNED    RED — git-workflow.md gains a #795/ADR-0015
#                           retirement anchor.
#     AC3-PRESERVE-MANUAL   guard (PASS pre+post) — the manual
#                           `git ls-tree HEAD services` check and the
#                           `blocked-by-subrepo` label survive.
#     AC3-XDOC-NOCONTRA     guard (PASS pre+post) — external-review-
#                           sequencing.md:31's existing retirement record
#                           is untouched (this issue does not own that file).
#
#   AC4 — tier-agnostic propagation-batching rule (defer until sub-repo PR
#         clean, one bump, exceptional interim bump records a reason):
#     AC4-DEFER              RED — HANDOFF step 6.5 gets the batching norm
#                           (blocked-by-review + defer/hold + once/single
#                           bump tokens together).
#     AC4-EXTREVSEQ           RED — external-review-sequencing.md gets a
#                           one-line cross-ref (not a full-text duplicate)
#                           pointing at HANDOFF step 6.5 as source of truth.
#     AC4-EXCEPTION           RED — step 6.5 gets the ASCII exception-format
#                           token `interim services bump` + a reason clause.
#     AC4-NO-NESTED-PRESUME   guard (PASS pre+post) — step 6.5 block never
#                           depends on nested/multi-tier/grandparent tokens
#                           (tier-agnostic rule; issue prose legitimately
#                           uses "nested" elsewhere, so this is scoped to
#                           the step 6.5 block only).
#
#   AC5 — ADR-0015 conformance (verification mechanism, not independent
#         content — Phase 3 R5):
#     AC5-ADR-CITED           RED — git-workflow.md gains an ADR-0015
#                           citation (subsumes into AC3-RETIRE-ALIGNED's
#                           anchor; asserted independently per design).
#     AC5-NO-REVIVE            guard (PASS pre+post) — the HANDOFF section
#                           of autoflow-guide.md never reintroduces
#                           `subrepo-merged` as a live machine status check
#                           (complements AC3, which owns the git-workflow.md
#                           site of this exact defect).
#
#   AC-SCOPE        guard — git diff --name-only ⊆ allow-list.
#   AC-CI-REGISTER  guard — this suite is wired into
#                   .github/workflows/e2e-dummy-target.yml (both `paths:`
#                   trigger blocks + a `run:` step), #798/#799/#800/#846
#                   precedent.
#
# Not in this file (verification design §3/§5 — Tier 2/Tier 3, delegated to
# a manual scenarios document, out of this RED spawn's scope per DISPATCH
# instructions — this Test AI pass touches only this suite):
#   AC2-BATCH-COHERENCE (AC2<->AC4 timing semantic judgment)   — Tier 2
#   AC4-TIER-AGNOSTIC (tier-agnosticism judgment)               — Tier 2
#   AC5-CROSSCHECK (ADR-0015 D1/D3 conformance judgment)        — Tier 2
#   AC1/AC2 live multi-repo pointer-bump behavior                — Tier 3
#   AC4 batching cost-savings observation                        — Tier 3
#
# RED expectation (pre-edit, this commit): AC1-DELIVER-MARKER,
# AC1-DELIVER-ACTOR, AC1-DELIVER-GITLINK, AC1-DELIVER-FORWARDREF,
# AC1-HANDOFF-STEP, AC1-OWNERSHIP-ROW, AC1-XREF, AC2-MUST,
# AC2-SOLE-DEFENSE, AC3-NO-LIVE-WORKFLOW, AC3-EXIT79-CTX,
# AC3-RETIRE-ALIGNED, AC4-DEFER, AC4-EXTREVSEQ, AC4-EXCEPTION,
# AC5-ADR-CITED all FAIL (target tokens/markers absent from current HEAD).
# All guards (AC1-NO-HOSTONLY-BLEED, AC1-XREF-NOCONTRA, AC2-NO-PERPUSH,
# AC3-PRESERVE-MANUAL, AC3-XDOC-NOCONTRA, AC4-NO-NESTED-PRESUME,
# AC5-NO-REVIVE) PASS pre-edit (nothing contradictory exists yet).
# AC-SCOPE PASS (test-only diff). AC-CI-REGISTER PASS once registered.
#
# Harness convention: set -uo pipefail, assert_true/assert_false, canonical
# `Results: P/T passed, F failed` line, exit 1 iff F>0.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AUTOFLOW_GUIDE="$PROJECT_ROOT/docs/autoflow-guide.md"
GIT_WORKFLOW="$PROJECT_ROOT/docs/git-workflow.md"
EXT_REVIEW_SEQ="$PROJECT_ROOT/docs/external-review-sequencing.md"
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
SUBMODULE_RULES="$PROJECT_ROOT/docs/submodule-common-rules.md"
CI_WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"

# Base ref for scope-containment diff guard (precedent: #797/#798/#799/#800/#846).
BASE_REF="${ISSUE_848_BASE_REF:-$(git -C "$PROJECT_ROOT" merge-base HEAD main 2>/dev/null || true)}"

PASS=0; FAIL=0; TESTS=0

# ---------------------------------------------------------------------------
# Helpers (assert_* pattern per tests/test-issue-800-doc-assertions.sh /
# tests/test-issue-846-doc-assertions.sh)
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
# Section extractors — scope discriminator greps to the exact target
# section/marker/numbered-item, never an absolute line number (verification
# design §0: this issue's own source citations had line-drift).
# ---------------------------------------------------------------------------

# ## DELIVER heading -> next ## heading (## INTEGRATE — Integration
# Verification is the next top-level heading in the current doc structure).
deliver_section() {
  awk '
    /^## DELIVER/ {f=1}
    f && /^## INTEGRATE — Integration Verification/ {exit}
    f {print}
  ' "$AUTOFLOW_GUIDE"
}

# Within the DELIVER section, the multi-repo `*Secondary (multi-repo):*`
# marker block (GREEN promotes the existing fenced 1.-3. list to this
# marker per feature design §3 AC1 item 1 / ledger E7). Pre-edit this marker
# does not exist, so the block is empty — every downstream discriminator on
# this block FAILs for that reason, which is the well-defined RED flip gate.
deliver_secondary_block() {
  deliver_section | awk '/\*Secondary \(multi-repo\):\*/{f=1} f{print}'
}

# The full HANDOFF numbered procedure (the fenced list starting at "1.
# Change summary ..." through its closing fence, before the "HANDOFF
# failure -> regression" / "Merge Sequencing" prose that follows).
handoff_procedure_block() {
  awk '
    /^1\. Change summary \(changed files, commit hashes/ {f=1}
    f && /^```$/ {exit}
    f {print}
  ' "$AUTOFLOW_GUIDE"
}

# HANDOFF step 3 (push the dev branch) — numbered-item marker "3." to the
# next numbered-item marker "4." (parity with AC4-NO-NESTED-PRESUME's
# step-6.5 bullet-marker scoping, ledger E8).
step3_block() {
  handoff_procedure_block | awk '
    /^3\. Push the dev branch:/ {f=1}
    f && /^4\. Create PR/ {exit}
    f {print}
  '
}

# HANDOFF step 4b (host PR creation) — the `b. Create the host PR ...` line
# through the next top-level numbered item "5. Confirm CI ...". This is the
# sole commit-format site (ledger E7) — DELIVER only forward-refs it.
step4b_block() {
  handoff_procedure_block | awk '
    /^ *b\. Create the host PR/ {f=1}
    f && /^5\. Confirm CI/ {exit}
    f {print}
  '
}

# HANDOFF step 6.5 (review triage) — "6.5. Review triage" to the next
# top-level numbered item "7." (the `.autoflow/issue-{N}.json` step).
step65_block() {
  handoff_procedure_block | awk '
    /^6\.5\. Review triage/ {f=1}
    f && /^7\./ {exit}
    f {print}
  '
}

# git-workflow.md "### Merge Sequencing (external review)" section, to the
# next "### Pointer reconciliation" heading.
merge_seq_section() {
  awk '
    /^### Merge Sequencing/ {f=1}
    f && /^### Pointer reconciliation/ {exit}
    f {print}
  ' "$GIT_WORKFLOW"
}

# git-workflow.md "### Pointer reconciliation" section, to the next "##"
# (top-level) heading ("## Post-Merge Cleanup").
pointer_reconcile_section() {
  awk '
    /^### Pointer reconciliation/ {f=1}
    f && /^## Post-Merge Cleanup/ {exit}
    f {print}
  ' "$GIT_WORKFLOW"
}

# CLAUDE.md "### Commit Ownership" table, to the next "###" heading
# ("### PR Flow").
commit_ownership_table() {
  awk '
    /^### Commit Ownership/ {f=1}
    f && /^### PR Flow/ {exit}
    f {print}
  ' "$CLAUDE_MD"
}

# submodule-common-rules.md "### Multi-developer concurrent work" through
# "### Sub-repo cycle close-out" (the cross-ref note may land at either
# :61's "only the submodule pointer" sentence or :69's close-out step 2 —
# feature design §3 AC1 item 4), stopping at the next distinct heading
# ("### Framework propagation").
multidev_closeout_section() {
  awk '
    /^### Multi-developer concurrent work/ {f=1}
    f && /^### Framework propagation/ {exit}
    f {print}
  ' "$SUBMODULE_RULES"
}

# Forbidden-condition helper for AC3-NO-LIVE-WORKFLOW / AC5-NO-REVIVE:
# a `handoff-sequence.yml` or "subrepo-merged status check" mention that is
# current-tense/active and carries no retirement token (#795, ADR-0015,
# retire, 은퇴) in the same scoped section.
live_machine_verify_no_retire() {
  local section="$1"
  if printf '%s\n' "$section" | grep -qiE 'handoff-sequence\.yml|machine-verifies|publishes.*status check.*machine evidence'; then
    if printf '%s\n' "$section" | grep -qiE '#795|ADR-0015|retire|은퇴'; then
      return 1
    fi
    return 0
  fi
  return 1
}

# Forbidden-condition helper for AC3-EXIT79-CTX: a `subrepo-merged`/`Exit 79`
# assertion attribution with no retirement token in the same scoped section.
live_exit79_no_retire() {
  local section="$1"
  if printf '%s\n' "$section" | grep -qiE 'subrepo-merged.*assertion|Exit 79'; then
    if printf '%s\n' "$section" | grep -qiE '#795|ADR-0015|retire|은퇴'; then
      return 1
    fi
    return 0
  fi
  return 1
}

# =============================================================================
echo "=== AC1-DELIVER-* (RED discriminators) — DELIVER *Secondary* marker block ==="

assert_true "AC1-DELIVER-MARKER: DELIVER section carries a '*Secondary (multi-repo):*' marker bullet (promoted from the fenced 1.-3. list)" \
  "ctx=\$(deliver_section); printf '%s\n' \"\$ctx\" | grep -qF '*Secondary (multi-repo):*'"
assert_true "AC1-DELIVER-ACTOR: the DELIVER *Secondary* marker block names the pointer-bump actor as orchestrator" \
  "ctx=\$(deliver_secondary_block); printf '%s\n' \"\$ctx\" | grep -qiF 'orchestrator'"
assert_true "AC1-DELIVER-GITLINK: the DELIVER *Secondary* marker block names the services gitlink/pointer target" \
  "ctx=\$(deliver_secondary_block); printf '%s\n' \"\$ctx\" | grep -qiE 'services.*(gitlink|pointer)|pointer.*services'"
assert_true "AC1-DELIVER-FORWARDREF: the DELIVER *Secondary* marker block forward-refs HANDOFF step 4b for the commit format" \
  "ctx=\$(deliver_secondary_block); printf '%s\n' \"\$ctx\" | grep -qiE 'step 4b|HANDOFF'"

# =============================================================================
echo ""
echo "=== AC1-HANDOFF-STEP (RED discriminator) — HANDOFF step 4b sole commit-format snippet ==="

assert_true "AC1-HANDOFF-STEP: HANDOFF step 4b carries 'git add services'" \
  "ctx=\$(step4b_block); printf '%s\n' \"\$ctx\" | grep -qF 'git add services'"
assert_true "AC1-HANDOFF-STEP: HANDOFF step 4b carries the canonical commit-message format 'chore(#N): bump services pointer to <short-sha>'" \
  "ctx=\$(step4b_block); printf '%s\n' \"\$ctx\" | grep -qF 'chore(#N): bump services pointer to <short-sha>'"

# =============================================================================
echo ""
echo "=== AC1-OWNERSHIP-ROW (RED discriminator) — CLAUDE.md Commit Ownership pointer-bump row ==="

assert_true "AC1-OWNERSHIP-ROW: Commit Ownership table has a pointer-bump row with committer Orchestrator" \
  "ctx=\$(commit_ownership_table); printf '%s\n' \"\$ctx\" | grep -qiE '\\|.*[Pp]ointer bump.*\\|.*Orchestrator'"

# =============================================================================
echo ""
echo "=== AC1-XREF (RED discriminator) — submodule-common-rules.md cross-ref note ==="

assert_true "AC1-XREF: submodule-common-rules.md reconciles 'only the submodule pointer' with the orchestrator actor" \
  "ctx=\$(multidev_closeout_section); printf '%s\n' \"\$ctx\" | grep -qiF 'orchestrator'"

# =============================================================================
echo ""
echo "=== AC1-NO-HOSTONLY-BLEED / AC1-XREF-NOCONTRA (guards, PASS pre+post) ==="

assert_false "AC1-NO-HOSTONLY-BLEED: the DELIVER host-only (default) paragraph (before any *Secondary* marker) never gains 'git add services'" \
  "deliver_section | awk '/\\*Secondary \\(multi-repo\\):\\*/{exit} {print}' | grep -qF 'git add services'"
assert_true "AC1-XREF-NOCONTRA: submodule-common-rules.md still states 'Each developer commits only the submodule pointer'" \
  "grep -qF 'Each developer commits **only the submodule pointer**' '$SUBMODULE_RULES'"

# =============================================================================
echo ""
echo "=== AC2-MUST / AC2-SOLE-DEFENSE (RED discriminators) — HANDOFF step 3 review-response re-bump ==="

assert_true "AC2-MUST: HANDOFF step 3 carries a [MUST] re-bump clause" \
  "ctx=\$(step3_block); printf '%s\n' \"\$ctx\" | grep -qF '[MUST]' && printf '%s\n' \"\$ctx\" | grep -qiE 're-?bump'"
assert_true "AC2-MUST: HANDOFF step 3 requires the 'git ls-tree HEAD services' verification" \
  "ctx=\$(step3_block); printf '%s\n' \"\$ctx\" | grep -qF 'git ls-tree HEAD services'"
assert_true "AC2-SOLE-DEFENSE: HANDOFF step 3 states the sole-defense English phrase 'only remaining'" \
  "ctx=\$(step3_block); printf '%s\n' \"\$ctx\" | grep -qF 'only remaining'"
assert_true "AC2-SOLE-DEFENSE: HANDOFF step 3 anchors the sole-defense clause to #795/ADR-0015" \
  "ctx=\$(step3_block); printf '%s\n' \"\$ctx\" | grep -qiE '#795|ADR-0015'"

# =============================================================================
echo ""
echo "=== AC2-NO-PERPUSH (guard, PASS pre+post) — step-3 block never mandates per-push re-bump ==="

assert_false "AC2-NO-PERPUSH: HANDOFF step 3 block does not mandate an unconditional per-push re-bump" \
  "ctx=\$(step3_block); printf '%s\n' \"\$ctx\" | grep -qiE 'each .*push.*re-?bump|every .*fix.*bump'"

# =============================================================================
echo ""
echo "=== AC3-NO-LIVE-WORKFLOW / AC3-EXIT79-CTX / AC3-RETIRE-ALIGNED (RED discriminators) ==="

assert_false "AC3-NO-LIVE-WORKFLOW: Merge Sequencing section does not describe handoff-sequence.yml as a live machine-verify without a retirement token" \
  "live_machine_verify_no_retire \"\$(merge_seq_section)\""
assert_false "AC3-EXIT79-CTX: Pointer-reconciliation section does not attribute Exit 79/subrepo-merged assertion 3 without a retirement token" \
  "live_exit79_no_retire \"\$(pointer_reconcile_section)\""
assert_true "AC3-RETIRE-ALIGNED: git-workflow.md carries a #795/ADR-0015 retirement anchor" \
  "grep -qiE '#795|ADR-0015' '$GIT_WORKFLOW'"

# =============================================================================
echo ""
echo "=== AC3-PRESERVE-MANUAL / AC3-XDOC-NOCONTRA (guards, PASS pre+post) ==="

assert_true "AC3-PRESERVE-MANUAL: Pointer-reconciliation section still requires the git ls-tree HEAD services manual check" \
  "ctx=\$(pointer_reconcile_section); printf '%s\n' \"\$ctx\" | grep -qF 'git ls-tree HEAD services'"
assert_true "AC3-PRESERVE-MANUAL: Merge Sequencing section still names the blocked-by-subrepo label" \
  "ctx=\$(merge_seq_section); printf '%s\n' \"\$ctx\" | grep -qF 'blocked-by-subrepo'"
assert_true "AC3-XDOC-NOCONTRA: external-review-sequencing.md still carries its #795/ADR-0015 D3 retirement record" \
  "grep -qF '#795' '$EXT_REVIEW_SEQ' && grep -qiF 'ADR-0015' '$EXT_REVIEW_SEQ'"

# =============================================================================
echo ""
echo "=== AC4-DEFER / AC4-EXTREVSEQ / AC4-EXCEPTION (RED discriminators) — propagation batching ==="

assert_true "AC4-DEFER: HANDOFF step 6.5 states the propagation-batching defer-until-clean rule" \
  "ctx=\$(step65_block); printf '%s\n' \"\$ctx\" | grep -qiF 'blocked-by-review' && printf '%s\n' \"\$ctx\" | grep -qiE 'defer|hold|보류|until.*clear' && printf '%s\n' \"\$ctx\" | grep -qiE 'once|1회|single bump'"
assert_true "AC4-EXTREVSEQ: external-review-sequencing.md carries a one-line cross-ref to HANDOFF step 6.5 for the batching norm" \
  "grep -qiE 'step 6\\.5' '$EXT_REVIEW_SEQ' && grep -qiE 'blocked-by-review' '$EXT_REVIEW_SEQ'"
assert_true "AC4-EXCEPTION: HANDOFF step 6.5 carries the ASCII exception commit-format token 'interim services bump'" \
  "ctx=\$(step65_block); printf '%s\n' \"\$ctx\" | grep -qF 'interim services bump'"
assert_true "AC4-EXCEPTION: HANDOFF step 6.5 requires the exception commit to record a reason" \
  "ctx=\$(step65_block); printf '%s\n' \"\$ctx\" | grep -qiE 'reason|commit message'"

# =============================================================================
echo ""
echo "=== AC4-NO-NESTED-PRESUME (guard, PASS pre+post) — step 6.5 block stays tier-agnostic ==="

assert_false "AC4-NO-NESTED-PRESUME: HANDOFF step 6.5 block does not depend on nested/multi-tier/grandparent tokens" \
  "ctx=\$(step65_block); printf '%s\n' \"\$ctx\" | grep -qiE 'nested|multi-tier|grandparent|다단'"

# =============================================================================
echo ""
echo "=== AC5-ADR-CITED (RED discriminator) / AC5-NO-REVIVE (guard, PASS pre+post) ==="

assert_true "AC5-ADR-CITED: git-workflow.md cites ADR-0015" \
  "grep -qiF 'ADR-0015' '$GIT_WORKFLOW'"
assert_false "AC5-NO-REVIVE: HANDOFF section of autoflow-guide.md does not reintroduce subrepo-merged as a live machine status check" \
  "live_machine_verify_no_retire \"\$(handoff_procedure_block)\""

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
    "docs/autoflow-guide.md"
    "docs/git-workflow.md"
    "docs/external-review-sequencing.md"
    "CLAUDE.md"
    "docs/submodule-common-rules.md"
    "tests/test-issue-848-doc-assertions.sh"
    "tests/manual/issue-848-manual-scenarios.md"
    ".github/workflows/e2e-dummy-target.yml"
    # Mechanical consequence of editing manifest-tracked docs: setup/manifest.json
    # sha256 regeneration (#799 precedent, commit 4c2f5a4).
    "setup/manifest.json"
    # Allow-list self-reference / sibling AC-SCOPE re-admission (verification
    # design §2 AC-SIBLING-ALLOWLIST — transitive gap exposed by #846 commits
    # d40d2a3/deebfc3/2c0570b): this cycle's RED suite lands on the same
    # branch as several sibling scope-guard tests, and this cycle's own
    # allow-list must re-admit those sibling files/suites in turn.
    "tests/test-issue-798-topology-flip.sh"
    "tests/test-issue-799-inert-cleanup.sh"
    "tests/test-issue-800-doc-assertions.sh"
    "tests/test-issue-846-doc-assertions.sh"
    "tests/manual/issue-846-manual-scenarios.md"
    "tests/test-issue-949-manifest-regen-doc.sh"
    "tests/test-issue-952-wizard-removal.sh"
    # #848 transitive: sibling guard-admission edits (b8b9ad6) land on this branch
    "tests/test-issue-794-doc-assertions.sh"
    "tests/test-issue-795-handoff-removal.sh"
    "tests/test-issue-955-subagent-background-ban.sh"
    # #951 merge admission (same AC-SIBLING-ALLOWLIST class as above): the
    # doc-invariant registry cycle (#951) merges origin/main (this suite's
    # cycle) into its branch, so #951's change surface — registry + runner +
    # base-ref lib + fixtures + its RED suite + sibling guard re-anchors —
    # lands in the same branch diff this guard scans (ledger E15 precedent:
    # df4641d / da11389 / fa12eb1).
    "docs/INDEX.md"
    "docs/doc-invariant-registry.md"
    "docs/maintained-docs.md"
    "tests/adr-0016-conformance-check.sh"
    "tests/fixtures/doc-invariants-anchor-fixture.md"
    "tests/fixtures/doc-invariants-baseline.txt"
    "tests/fixtures/doc-invariants-dialect-fixture.md"
    "tests/fixtures/doc-invariants.json"
    "tests/lib/base-ref.sh"
    "tests/manual/issue-951-manual-scenarios.md"
    "tests/run-doc-invariants.sh"
    "tests/test-issue-951-registry.sh"
    "tests/test-issue-964-sigpipe-safe-pipes.sh"
    "tests/test-issue-843-doc-assertions.sh"
    "tests/test-issue-796-doc-assertions.sh"
    "tests/test-issue-797-doc-invocation.sh"
    # #978 cycle files (concurrent-cycle registration, cc8030d precedent):
    # archive-semantics GREEN rewrites the cleanup wrapper in place; the RED
    # pass re-targets the boundary guard, adds the repo-key guard, and
    # updates the #844 suite's AC1-b/AC1-c delete->archive assertions
    # (CLAUDE.md / docs / setup/manifest.json / doc-invariants.json /
    # e2e workflow already admitted above).
    "scripts/cleanup/cleanup-issue.sh"
    "scripts/test/check-cleanup-issue-boundary.sh"
    "scripts/test/check-repo-key.sh"
    "tests/test-issue-844-doc-assertions.sh"
    # #11 cycle files: plugin-namespaced spawn-role fix — dual-pattern hook
    # arms (both copies), P3 doc row, gate-hardening RED oracles.
    ".claude/hooks/check-autoflow-gate.sh"
    "plugin/autoflow/hooks/check-autoflow-gate.sh"
    "docs/gate-matching-standard.md"
    "tests/test-gate-hardening.sh"
    # #18 cycle files: fixture-glob isolation fix — locale-invariance
    # manifest regression update + new glob-isolation RED oracle.
    "tests/test-issue-16-manifest-locale-invariance.sh"
    "tests/test-issue-18-fixture-glob-isolation.sh"
    # #6 cycle file: severity-parse fail-loud + '='-tolerant grammar RED
    # suite (per-issue test isolation, #18 precedent).
    "tests/test-issue-6-severity-parse-contract.sh"
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
  assert_true "AC-CI-a: e2e-dummy-target.yml references test-issue-848-doc-assertions.sh" \
    "grep -q 'test-issue-848-doc-assertions' '$CI_WORKFLOW'"
  assert_true "AC-CI-b: reference appears in a 'paths:' trigger block" \
    "ctx=\$(grep -B30 'test-issue-848-doc-assertions' '$CI_WORKFLOW'); printf '%s\n' \"\$ctx\" | grep -q '^ *paths:'"
  assert_true "AC-CI-c: reference appears in a 'run:' step" \
    "ctx=\$(grep -A2 'name:.*#848\\|test-issue-848-doc-assertions' '$CI_WORKFLOW'); printf '%s\n' \"\$ctx\" | grep -q 'run: bash tests/test-issue-848-doc-assertions.sh'"
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
