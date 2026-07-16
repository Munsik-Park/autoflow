#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Static conformance check: ADR-0016 (ADR-conformance gate scoring) — Issue #818
# =============================================================================
# NOT a jest suite. Issue #818's deliverable is a decision document (an ADR),
# not a runtime code artifact (Verification Design §0/§2), so verification is
# a static document-conformance checklist: heading presence + in-block phrase
# greps against the committed ADR, plus a source-anchor re-derivation against
# the hook script and docs/phases/analysis.md. Every grep target and its
# block scope is locked to .autoflow/issue-818-verification-design.md §1.1 /
# §1.1.1, reconciled with .autoflow/issue-818-feature-design.md §8's committed
# nine-token skeleton.
#
# RED expectation (cycle 1 commit): the ADR file
# docs/adr/0016-adr-conformance-gate-scoring.md does not exist yet (GREEN has
# not authored it). Every AC1-AC6 heading-presence and in-block check that
# depends on the ADR file FAILs. The independent source-anchor checks (hook
# script fact re-derivation, docs/phases/analysis.md DENY line, README status
# values) are pre-existing invariants and PASS before and after GREEN — they
# are guards, not RED discriminators.
#
# Cycle 2 (review-response, issue #818 Codex Medium finding): ADR-0016 shipped
# in cycle 1 but was not registered in docs/maintained-docs.md's ADR table nor
# linked from docs/INDEX.md's Quick Routing. AC-R1/AC-R2/AC-R3 below (added
# this commit) check that registration-completeness fix, per
# .autoflow/issue-818-verification-design.md (cycle 2) §1. RED expectation
# (this commit): AC-R1 and AC-R2 FAIL now (the registry rows do not exist
# yet). AC-R3 (manifest sha256 freshness for the two docs, and artifact-count
# invariance) PASSes now — the docs are still unedited, so nothing is stale
# yet; AC-R3 is a regression guard that becomes a discriminator only if GREEN
# edits the docs without regenerating the manifest (§3-G, R-B).
#
# Cycle 3 (issue #961, ADR-0016 gate-wiring follow-up): propagates the
# already-Accepted ADR-0016 decision into the operative rubric/contract docs
# (autoflow-guide.md GATE:PLAN/GATE:QUALITY/ARCHITECT, evaluation-system.md,
# teammate-contracts.md) and promotes ADR-0016 Status Proposed -> Accepted.
# AC-961-1/-2/-5/-7 below (added this commit), per
# .autoflow/issue-961-verification-design.md §4. RED expectation (this
# commit): AC-961-1, AC-961-2, AC-961-5, AC-961-7 all FAIL now (the prose
# inserts and the Status/README flips have not landed); the existing AC1-b
# assertion above was flipped in this same commit to expect 'Accepted' and
# also FAILs now (the ADR file still states 'Proposed'). AC1-guard
# (README Status Values legend) is untouched and stays green throughout.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ADR="$PROJECT_ROOT/docs/adr/0016-adr-conformance-gate-scoring.md"
ADR_README="$PROJECT_ROOT/docs/adr/README.md"
HOOK="$PROJECT_ROOT/.claude/hooks/check-autoflow-gate.sh"
ANALYSIS_MD="$PROJECT_ROOT/docs/phases/analysis.md"
MAINTAINED_DOCS="$PROJECT_ROOT/docs/maintained-docs.md"
INDEX_MD="$PROJECT_ROOT/docs/INDEX.md"
MANIFEST="$PROJECT_ROOT/setup/manifest.json"
AUTOFLOW_GUIDE="$PROJECT_ROOT/docs/autoflow-guide.md"
EVAL_SYSTEM="$PROJECT_ROOT/docs/evaluation-system.md"
TEAMMATE_CONTRACTS="$PROJECT_ROOT/docs/teammate-contracts.md"

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

# Block-scoped extractor (Verification Design §1.1.1): emit only the lines
# inside the named heading's block (any level "^#+ <heading>"), terminating at
# the next heading of any level. Runs against the ADR file only.
block() {
  local heading="$1"
  awk -v h="$heading" '$0 ~ ("^#+ " h){f=1;next} f&&/^#+ /{f=0} f' "$ADR" 2>/dev/null
}

# =============================================================================
echo "=== AC1 — Decision + rationale recorded as an ADR ==="

assert_true "AC1-a: ADR file exists at docs/adr/0016-adr-conformance-gate-scoring.md" \
  "[ -f '$ADR' ]"
assert_true "AC1-b: '## Status' section states 'Accepted' (flipped post-#961 owner promotion; issue #961 AC10)" \
  "block 'Status' | grep -q 'Accepted'"
assert_true "AC1-c: '## Decision' heading present (level-tolerant)" \
  "grep -nE '^#{2,4} Decision' '$ADR' 2>/dev/null"
assert_true "AC1-d: verbatim lowercase verdict token 'Decision: adopt' present inside the Decision block (case-sensitive)" \
  "block 'Decision' | grep -q 'Decision: adopt'"
assert_true "AC1-e: '### Rationale' heading present (level-tolerant), distinct from the verdict token" \
  "grep -nE '^#{2,4} Rationale' '$ADR' 2>/dev/null"
assert_true "AC1-f: README 'Current Drafts' table gains a '0016-adr-conformance' row" \
  "grep -q '0016-adr-conformance' '$ADR_README'"

# Baseline invariant (should PASS before and after GREEN): README documents
# the four allowed Status values.
assert_true "AC1-guard: README Status Values lists Proposed/Accepted/Deprecated/Superseded" \
  "grep -qE '\`Proposed\`' '$ADR_README' && grep -qE '\`Accepted\`' '$ADR_README' && grep -qE '\`Deprecated\`' '$ADR_README' && grep -qE '\`Superseded\`' '$ADR_README'"

# =============================================================================
echo ""
echo "=== AC2 — placement, item form, N/A convention ==="

assert_true "AC2-a: '### Placement' heading present (level-tolerant)" \
  "grep -nE '^#{2,4} Placement' '$ADR' 2>/dev/null"
assert_true "AC2-b: Placement block names ARCHITECT" \
  "block 'Placement' | grep -q 'ARCHITECT'"
assert_true "AC2-c: Placement block names GATE:PLAN" \
  "block 'Placement' | grep -q 'GATE:PLAN'"
assert_true "AC2-d: Placement block names GATE:QUALITY" \
  "block 'Placement' | grep -q 'GATE:QUALITY'"
assert_true "AC2-e: Placement block names the Feasibility cap target in-block" \
  "block 'Placement' | grep -qi 'Feasibility'"
assert_true "AC2-f: Placement block names the Scope cap target in-block" \
  "block 'Placement' | grep -qi 'Scope'"

assert_true "AC2-g: '### Item form' heading present (level-tolerant)" \
  "grep -nE '^#{2,4} Item form' '$ADR' 2>/dev/null"
assert_true "AC2-h: Item form block states 'caps the named item at 6'" \
  "block 'Item form' | grep -qiE 'cap.*(named item|at 6)'"
assert_true "AC2-i: Item form block states 'not a new scored item'" \
  "block 'Item form' | grep -qiE 'not a new scored item'"

assert_true "AC2-j: '### N/A convention' heading present (level-tolerant)" \
  "grep -nE '^#{2,4} N/A convention' '$ADR' 2>/dev/null"
assert_true "AC2-k: N/A convention block states the Conforms outcome (no cap)" \
  "block 'N/A convention' | grep -qi 'Conform'"
assert_true "AC2-l: N/A convention block states the Diverges/undocumented outcome (cap 6)" \
  "block 'N/A convention' | grep -qiE 'diverge|undocumented'"
assert_true "AC2-m: N/A convention block states N/A is the default for a change touching no ADR-decision surface" \
  "block 'N/A convention' | grep -qiE 'default'"

# =============================================================================
echo ""
echo "=== AC3 — threshold & hook cascade (chain-impact invariance) ==="

assert_true "AC3-a: '### Threshold & hook cascade' heading present (level-tolerant)" \
  "grep -nE '^#{2,4} Threshold' '$ADR' 2>/dev/null"
assert_true "AC3-b: Threshold block asserts no new scores key" \
  "block 'Threshold' | grep -qiE 'no new .*key'"
assert_true "AC3-c: Threshold block asserts no hook edit" \
  "block 'Threshold' | grep -qiE 'no hook (edit|change)'"
assert_true "AC3-d: Threshold block asserts no threshold recompute" \
  "block 'Threshold' | grep -qiE 'no threshold (recompute|recalculat)'"

# Block-scoped factual-error flags (guards; the Alternatives Considered
# section is the permitted home for the rejected new-item form's N+1
# arithmetic — these greps are scoped to the Threshold block only, never
# file-wide, per Verification Design §1.1.1).
assert_false "AC3-guard-a: Threshold block does not claim a hook edit is required" \
  "block 'Threshold' | grep -qiE 'requires? (a )?hook (edit|change|modification)'"
assert_false "AC3-guard-b: Threshold block does not claim a threshold recompute is required" \
  "block 'Threshold' | grep -qiE '(requires?|needs?) .*threshold (recompute|recalculat)'"
assert_false "AC3-guard-c: Threshold block does not describe N+1-item averaging as the chosen form's behavior" \
  "block 'Threshold' | grep -qiE 'n\\+1|averag(e|ing) over.*(additional|new) item'"

# Independent fact re-derivation against the hook script (invariant; should
# PASS before and after GREEN — this cycle adds no hook code).
assert_true "AC3-hook-a: check_scores computes avg via add/length (item-count-agnostic)" \
  "grep -qE 'add / length' '$HOOK'"
assert_true "AC3-hook-b: check_scores reads security by key name" \
  "grep -qF '.[\"security\"]' '$HOOK'"
assert_true "AC3-hook-c: cap fires via the pre-existing \$min < 7 branch" \
  "grep -qF '\$min < 7' '$HOOK'"

# =============================================================================
echo ""
echo "=== AC4 — DIAGNOSE non-contradiction ==="

assert_true "AC4-a: '### DIAGNOSE consistency' heading present (level-tolerant)" \
  "grep -nE '^#{2,4} DIAGNOSE consistency' '$ADR' 2>/dev/null"

# Source-anchor integrity (content-anchored, line-number-independent):
# invariant, should PASS before and after GREEN.
assert_true "AC4-guard-a: analysis.md [DENY] on injecting ADR-candidate docs is live" \
  "grep -qE '\\[DENY\\].*INDEX\\.md' '$ANALYSIS_MD'"
assert_true "AC4-guard-b: analysis.md whitelist row denies ADR candidates to all three roles" \
  "grep -qE 'ADR candidates.*denied.*denied.*denied' '$ANALYSIS_MD'"

# =============================================================================
echo ""
echo "=== AC5 — case-collection result recorded ==="

assert_true "AC5-a: '### Case collection' heading present (level-tolerant)" \
  "grep -nE '^#{2,4} Case collection' '$ADR' 2>/dev/null"

# =============================================================================
echo ""
echo "=== AC6 — follow-up implementation scope separated ==="

assert_true "AC6-a: '### Follow-up scope' heading present (level-tolerant)" \
  "grep -nE '^#{2,4} Follow-up scope' '$ADR' 2>/dev/null"

# =============================================================================
# Cycle 2 (review-response) — registration-completeness fix
# Verification Design (cycle 2) §1.1: block-scoped extractor generalized to an
# arbitrary <heading, file> pair (the cycle-1 block() above is ADR-file-only).
block_file() {
  local heading="$1" file="$2"
  awk -v h="$heading" '$0 ~ ("^#+ " h){f=1;next} f&&/^#+ /{f=0} f' "$file" 2>/dev/null
}

echo ""
echo "=== AC-R1 — maintained-docs.md ADR table registers ADR-0016 (cycle 2) ==="

assert_true "AC-R1-a: a 0016 row exists inside the ADRs table block of maintained-docs.md" \
  "block_file 'ADRs' '$MAINTAINED_DOCS' | grep -q '0016-adr-conformance-gate-scoring.md'"
assert_true "AC-R1-b: the matched line is a real 4-column table row (leading + internal pipes)" \
  "block_file 'ADRs' '$MAINTAINED_DOCS' | grep -qE '^\| .*0016-adr-conformance-gate-scoring\.md.*\| .*\| .*\|'"

# =============================================================================
echo ""
echo "=== AC-R2 — INDEX.md AutoFlow rules/gates row references ADR-0016 (cycle 2) ==="

assert_true "AC-R2-a: the 'AutoFlow rules, gates...' routing row references ADR-0016" \
  "grep -E '^\| AutoFlow rules, gates.*0016-adr-conformance' '$INDEX_MD'"
assert_false "AC-R2-b: that row does not use a markdown-link form to the ADR (backtick inline-code form required, not '](adr/0016...)')" \
  "grep -E '^\| AutoFlow rules, gates.*\]\((docs/)?adr/0016' '$INDEX_MD'"

# =============================================================================
echo ""
echo "=== AC-R3 — manifest sha256 freshness for the two edited docs (cycle 2 regression guard) ==="

assert_true "AC-R3-a: manifest sha256 for docs/maintained-docs.md matches current source hash" \
  "[ \"\$(jq -r '.artifacts[] | select(.source==\"docs/maintained-docs.md\") | .sha256' '$MANIFEST')\" = \"\$(shasum -a 256 '$MAINTAINED_DOCS' | awk '{print \$1}')\" ]"
assert_true "AC-R3-b: manifest sha256 for docs/INDEX.md matches current source hash" \
  "[ \"\$(jq -r '.artifacts[] | select(.source==\"docs/INDEX.md\") | .sha256' '$MANIFEST')\" = \"\$(shasum -a 256 '$INDEX_MD' | awk '{print \$1}')\" ]"
# #951 retired-guard disposition: docs/doc-invariant-registry.md enters the
# manifest's markdown-link closure this cycle (a hard requirement, ledger
# E14/§DR-8 — linking it from docs/INDEX.md deterministically pulls in one
# additive source+sha256 row). This cycle-2 regression guard's "stays 35"
# baseline predates that addition; narrowed to admit exactly that one
# expected artifact — a genuinely unexpected count (neither 35 nor 36, or an
# artifact list not containing the new doc) still FAILs.
#
# #979 lockstep update: the reviewer-backend-selection delivery surface
# (feature design §4 rows 1-6, GATE:PLAN PASS avg 9.0, ledger E12) adds six
# more manifest rows on top of the #951 closure baseline (36 -> 42): three
# copy rows (scripts/review/codex-review-pr.sh, scripts/preflight/check-
# review-backend.sh, .codex/review.md), two scaffold rows (AGENTS.md,
# .claude/autoflow.local.json), plus docs/reviewer-backend.md via the same
# markdown-link doc-closure mechanism as #951. The guard is widened the same
# way it was widened for the 951 cycle: admit exactly 42 solely via the
# presence of docs/reviewer-backend.md (the new closure-doc row) — a count
# that is neither 36 nor 42, or a 42 lacking that specific doc, still FAILs.
#
# #979 cycle-9 lockstep update (ledger E13): the GATE:PLAN-approved reviewer-
# isolation design factors the reviewer-backend probe env scrub into a
# shared lib, scripts/review/lib/claude-isolation.sh, delivered as one
# additive copy row on top of the 42-row #979 closure baseline (42 -> 43).
# The guard is narrowed the same way as the 36/42 arms above: admit exactly
# 43 solely via the presence of that one new manifest row — a count that is
# neither 35, 36, 42, nor 43, or a 43 lacking that specific source, still
# FAILs.
#
# #985 lockstep update (ledger Q1, GATE:QUALITY): the public-release doc
# sweep nets back down from the 43-row #979-cycle-9 baseline to 42 via two
# offsetting manifest-row changes on the same commit — docs/adr/0001-*.md's
# row is removed (ADR deleted from the public tree) while
# docs/improvement-backlog.md's row is restored (ledger Q1 empty-start
# restore, superseding the doc's original full deletion) — a coincidental
# same count as the #979 42-row baseline but a different row composition.
# The guard is widened with a #985-specific arm so a 42 reached via this
# swap is admitted on its own grounds, not merely via the #979 branch above:
# admit 42 also when docs/improvement-backlog.md is present AND no
# docs/adr/0001-*.md row survives — a 42 satisfying neither the #979 nor the
# #985 arm still FAILs.
#
# issue-#10 arm (ledger, GATE:PLAN this cycle): the manifest-registration-gap
# fix adds 4 root-layer/copy rows for methodology-step scripts the stamped
# docs already instruct a consumer to run (scripts/preflight/scan-cross-
# issue-recurrence.sh, scripts/handoff/emit-cycle-digest.sh, scripts/handoff/
# create-host-pr.sh, scripts/cleanup/cleanup-issue.sh), on top of the 42-row
# #979/#985 baseline (42 -> 46). The guard is widened the same single-witness
# way as the 36/43 arms above: admit exactly 46 solely via the presence of
# the scripts/cleanup/cleanup-issue.sh row (a source unique to this change)
# — a count that is neither 35, 36, 42, 43, nor 46, or a 46 lacking that
# specific row, still FAILs.
assert_true "AC-R3-c: manifest artifact count stays 35, is 36 solely via the #951 docs/doc-invariant-registry.md manifest-closure row (ledger E14), is 42 solely via the #979 reviewer-backend-selection delivery rows (docs/reviewer-backend.md closure, ledger E12) or the #985 adr/0001-removed + improvement-backlog.md-restored net-zero swap (ledger Q1), is 43 solely via the #979 cycle-9 scripts/review/lib/claude-isolation.sh manifest row (ledger E13), or is 46 solely via the issue-#10 scripts/cleanup/cleanup-issue.sh manifest row" \
  "count=\$(jq '.artifacts | length' '$MANIFEST'); [ \"\$count\" = \"35\" ] || { [ \"\$count\" = \"36\" ] && jq -e '.artifacts[] | select(.source == \"docs/doc-invariant-registry.md\")' '$MANIFEST' >/dev/null 2>&1; } || { [ \"\$count\" = \"42\" ] && jq -e '.artifacts[] | select(.source == \"docs/reviewer-backend.md\")' '$MANIFEST' >/dev/null 2>&1; } || { [ \"\$count\" = \"42\" ] && jq -e '.artifacts[] | select(.source == \"docs/improvement-backlog.md\")' '$MANIFEST' >/dev/null 2>&1 && ! jq -e '.artifacts[] | select(.source | test(\"^docs/adr/0001-\"))' '$MANIFEST' >/dev/null 2>&1; } || { [ \"\$count\" = \"43\" ] && jq -e '.artifacts[] | select(.source == \"scripts/review/lib/claude-isolation.sh\")' '$MANIFEST' >/dev/null 2>&1; } || { [ \"\$count\" = \"46\" ] && jq -e '.artifacts[] | select(.source == \"scripts/cleanup/cleanup-issue.sh\")' '$MANIFEST' >/dev/null 2>&1; }"

# =============================================================================
# Cycle 3 (issue #961) — ADR-0016 gate-wiring propagation into operative docs
# Verification Design (issue #961) §4: block_file() generalizes the ADR-only
# block() extractor to an arbitrary <heading, file> pair; reused here for
# autoflow-guide.md / evaluation-system.md / teammate-contracts.md windows.
# =============================================================================

echo ""
echo "=== AC-961-1 — autoflow-guide.md GATE:PLAN / GATE:QUALITY / ARCHITECT prose (feature AC1+AC2+AC3) ==="

# [MUST] section-window scoping (T-CAP collision guard — verification §AC1):
# T-CAP ('caps the named item at 6') already occurs verbatim at the
# pre-existing GATE:QUALITY blind-spot intro (autoflow-guide.md:486), so these
# GATE:PLAN checks are scoped to the NEW '### ADR-conformance check' subsection
# window only (block_file below), never a file-global grep.
assert_true "AC-961-1-a: new '### ADR-conformance check' subsection heading present in autoflow-guide.md" \
  "grep -nE '^#{2,4} ADR-conformance check' '$AUTOFLOW_GUIDE' 2>/dev/null"
assert_true "AC-961-1-b: ADR-conformance check subsection (GATE:PLAN) names both Feasibility and Scope" \
  "block_file 'ADR-conformance check' '$AUTOFLOW_GUIDE' | grep -q 'Feasibility' && block_file 'ADR-conformance check' '$AUTOFLOW_GUIDE' | grep -q 'Scope'"
assert_true "AC-961-1-c: ADR-conformance check subsection carries T-CAP verbatim ('caps the named item at 6'), window-scoped" \
  "block_file 'ADR-conformance check' '$AUTOFLOW_GUIDE' | grep -qF 'caps the named item at 6'"
assert_true "AC-961-1-d: ADR-conformance check subsection carries T-TRIG-1 verbatim ('divergence from a governing ADR')" \
  "block_file 'ADR-conformance check' '$AUTOFLOW_GUIDE' | grep -qF 'divergence from a governing ADR'"
assert_true "AC-961-1-e: ADR-conformance check subsection carries T-TRIG-2 verbatim ('architecture-impacting change with no governing ADR/owner decision')" \
  "block_file 'ADR-conformance check' '$AUTOFLOW_GUIDE' | grep -qF 'architecture-impacting change with no governing ADR/owner decision'"
assert_true "AC-961-1-f: ADR-conformance check subsection carries T-NA verbatim ('N/A by default')" \
  "block_file 'ADR-conformance check' '$AUTOFLOW_GUIDE' | grep -qF 'N/A by default'"
# Item-specific token (NOT the file-global T-CAP) — grep-confirmed absent
# pre-edit, so this attributes to the new insert rather than to landed prose.
assert_true "AC-961-1-g: GATE:QUALITY blind-spot list carries item-specific 'caps Fit at 6'" \
  "block_file 'Known blind-spot checks' '$AUTOFLOW_GUIDE' | grep -qF 'caps Fit at 6'"
assert_true "AC-961-1-h: ARCHITECT Agreement criteria carries T-NONSCORED verbatim ('a divergence is a COUNTER, not an ACCEPT')" \
  "block_file 'Agreement criteria' '$AUTOFLOW_GUIDE' | grep -qF 'a divergence is a COUNTER, not an ACCEPT'"

# =============================================================================
echo ""
echo "=== AC-961-2 — evaluation-system.md / teammate-contracts.md mirror, non-contradiction (feature AC4+AC5) ==="

assert_true "AC-961-2-a: evaluation-system.md GATE:PLAN row names the embedded ADR-conformance check" \
  "grep -E '^\| Plan evaluation \(GATE:PLAN\).*ADR-conformance' '$EVAL_SYSTEM'"
assert_true "AC-961-2-b: evaluation-system.md GATE:QUALITY row names the embedded ADR-conformance check" \
  "grep -E '^\| Quality evaluation \(GATE:QUALITY\).*ADR-conformance' '$EVAL_SYSTEM'"
assert_true "AC-961-2-c: teammate-contracts.md Facilitator Responsibilities names ADR conformance as a first-exchange axis" \
  "block_file 'Responsibilities' '$TEAMMATE_CONTRACTS' | grep -qi 'ADR conformance'"

# Cross-doc invariant (the real drift risk per Phase B Approach 2): the cap
# surface named in evaluation-system.md string-matches the surface named in
# autoflow-guide.md — same three item names co-occur with the cap in both.
assert_true "AC-961-2-d: cross-doc cap-surface co-occurrence — evaluation-system.md GATE:PLAN row names Feasibility, Scope, and the cap value 6" \
  "grep -E '^\| Plan evaluation \(GATE:PLAN\)' '$EVAL_SYSTEM' | grep -q 'Feasibility' && grep -E '^\| Plan evaluation \(GATE:PLAN\)' '$EVAL_SYSTEM' | grep -q 'Scope' && grep -E '^\| Plan evaluation \(GATE:PLAN\)' '$EVAL_SYSTEM' | grep -qF '6'"
assert_true "AC-961-2-e: cross-doc cap-surface co-occurrence — evaluation-system.md GATE:QUALITY row names Fit and the cap value 6" \
  "grep -E '^\| Quality evaluation \(GATE:QUALITY\)' '$EVAL_SYSTEM' | grep -q 'Fit' && grep -E '^\| Quality evaluation \(GATE:QUALITY\)' '$EVAL_SYSTEM' | grep -qF '6'"

# [MUST] intro reference-integrity assertion (Round-2 counter — feature §2 /
# verification §AC2). Appending a 4th blind-spot bullet under the unchanged
# intro breaks its hard count ('Three defect patterns ... caught only by
# external (Codex) review') — grep-confirmed present pre-edit at
# autoflow-guide.md:481, so its removal is a real RED->GREEN transition.
assert_false "AC-961-2-f: GATE:QUALITY blind-spot intro no longer hard-counts 'Three defect patterns'" \
  "block_file 'Known blind-spot checks' '$AUTOFLOW_GUIDE' | grep -qF 'Three defect patterns'"
assert_true "AC-961-2-g: GATE:QUALITY blind-spot section carries a distinct-provenance marker for the proactive ADR-0016 check (not a Codex catch)" \
  "block_file 'Known blind-spot checks' '$AUTOFLOW_GUIDE' | grep -qiE 'proactively-added|ADR-0016'"

# =============================================================================
echo ""
echo "=== AC-961-5 — ADR-0016 Status Proposed->Accepted + owner-approval evidence + README row (feature AC7+AC10) ==="

# NOTE: the AC1-b assertion above (this file, AC1 block) was flipped in this
# same commit to expect 'Accepted' instead of 'Proposed' — that is the
# load-bearing AC10 catch (feature §7). It is not repeated here; only the
# distinct owner-approval evidence line and the README row flip are new.
assert_true "AC-961-5-a: ADR '## Status' block carries the 'Owner approval: 2026-07-08' evidence line" \
  "block 'Status' | grep -qF 'Owner approval: 2026-07-08'"
assert_true "AC-961-5-b: docs/adr/README.md 0016 row status flipped to Accepted" \
  "grep -E '0016-adr-conformance-gate-scoring\\.md.*\\| *Accepted *\\|' '$ADR_README'"

# =============================================================================
echo ""
echo "=== AC-961-7 — docs/adr/README.md numbering-gap note (feature AC8) ==="

assert_true "AC-961-7-a: README numbering-gap note names the migrated range 0002, 0004-0014" \
  "grep -qE '0002,? *0004.{0,3}0014' '$ADR_README'"
assert_true "AC-961-7-b: README numbering-gap note attributes the migration to the 2026-06-27 split -> services/librechat-deploy" \
  "grep -q '2026-06-27' '$ADR_README' && grep -qF 'services/librechat-deploy' '$ADR_README'"
assert_true "AC-961-7-c: README numbering-gap note cross-references docs/maintained-docs.md as the authoritative registry" \
  "grep -qF 'maintained-docs.md' '$ADR_README'"

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
