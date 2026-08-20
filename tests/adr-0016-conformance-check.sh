#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: docs/adr/ docs/maintained-docs.md docs/INDEX.md
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
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
# not authored it). Every AC1/AC2/AC3 heading-presence and in-block check that
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
# AC-961-1/-2 below (added this commit), per
# .autoflow/issue-961-verification-design.md §4. RED expectation (this
# commit): AC-961-1 and AC-961-2 FAIL now (the prose inserts have not
# landed); the existing AC1-b assertion above was flipped in this same commit
# to expect 'Accepted' and also FAILs now (the ADR file still states
# 'Proposed'). AC1-guard (README Status Values legend) is untouched and stays
# green throughout.
#
# Migrated out of this file, assertion carried elsewhere (issue #109, registry
# §13.2 — the assert-less section headers were removed; carriers are
# `tests/fixtures/doc-invariants.json` ids):
#   DIAGNOSE non-contradiction   → adr0016-AC4-a-diagnose-heading
#   case-collection result       → adr0016-AC5-a-casecollection-heading
#   follow-up scope separated    → adr0016-AC6-a-followup-heading
#   Status flip + owner approval → adr0016-AC961-5-a-owner-approval,
#                                  adr0016-AC961-5-b-readme-accepted
#   docs/adr/README.md numbering-gap note
#                                → adr0016-AC961-7-a-range,
#                                  adr0016-AC961-7-b-date,
#                                  adr0016-AC961-7-b-repo,
#                                  adr0016-AC961-7-c-registry
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

# Baseline invariant (should PASS before and after GREEN): README documents
# the four allowed Status values.

# =============================================================================
echo ""
echo "=== AC2 — placement, item form, N/A convention ==="

assert_true "AC2-e: Placement block names the Feasibility cap target in-block" \
  "block 'Placement' | grep -qi 'Feasibility'"
assert_true "AC2-f: Placement block names the Scope cap target in-block" \
  "block 'Placement' | grep -qi 'Scope'"

assert_true "AC2-h: Item form block states 'caps the named item at 6'" \
  "block 'Item form' | grep -qiE 'cap.*(named item|at 6)'"
assert_true "AC2-i: Item form block states 'not a new scored item'" \
  "block 'Item form' | grep -qiE 'not a new scored item'"

assert_true "AC2-k: N/A convention block states the Conforms outcome (no cap)" \
  "block 'N/A convention' | grep -qi 'Conform'"
assert_true "AC2-l: N/A convention block states the Diverges/undocumented outcome (cap 6)" \
  "block 'N/A convention' | grep -qiE 'diverge|undocumented'"
assert_true "AC2-m: N/A convention block states N/A is the default for a change touching no ADR-decision surface" \
  "block 'N/A convention' | grep -qiE 'default'"

# =============================================================================
echo ""
echo "=== AC3 — threshold & hook cascade (chain-impact invariance) ==="

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

# Capture-then-match (docs/submodule-common-rules.md:212, issues #964/#973,
# GATE:QUALITY E36/E37): block_file's buffered output piped directly into a
# short-circuiting `grep -q` can SIGPIPE the producer under `set -o
# pipefail`. Captured once and reused across both checks below.
ADR_R1_CTX="$(block_file 'ADRs' "$MAINTAINED_DOCS")"
assert_true "AC-R1-a: a 0016 row exists inside the ADRs table block of maintained-docs.md" \
  "printf '%s\n' \"\$ADR_R1_CTX\" | grep -q '0016-adr-conformance-gate-scoring.md'"
assert_true "AC-R1-b: the matched line is a real 4-column table row (leading + internal pipes)" \
  "printf '%s\n' \"\$ADR_R1_CTX\" | grep -qE '^\| .*0016-adr-conformance-gate-scoring\.md.*\| .*\| .*\|'"

# =============================================================================
echo ""
echo "=== AC-R2 — INDEX.md AutoFlow rules/gates row references ADR-0016 (cycle 2) ==="

assert_false "AC-R2-b: that row does not use a markdown-link form to the ADR (backtick inline-code form required, not '](adr/0016...)')" \
  "grep -E '^\| AutoFlow rules, gates.*\]\((docs/)?adr/0016' '$INDEX_MD'"

# =============================================================================
echo ""
echo "=== AC-R3 — manifest sha256 freshness for the two edited docs (cycle 2 regression guard) ==="

assert_true "AC-R3-a: manifest sha256 for docs/maintained-docs.md matches current source hash" \
  "[ \"\$(jq -r '.artifacts[] | select(.source==\"docs/maintained-docs.md\") | .sha256' '$MANIFEST')\" = \"\$(shasum -a 256 '$MAINTAINED_DOCS' | awk '{print \$1}')\" ]"
assert_true "AC-R3-b: manifest sha256 for docs/INDEX.md matches current source hash" \
  "[ \"\$(jq -r '.artifacts[] | select(.source==\"docs/INDEX.md\") | .sha256' '$MANIFEST')\" = \"\$(shasum -a 256 '$INDEX_MD' | awk '{print \$1}')\" ]"
# AC-R3-c (manifest artifact-count allow-list) — RETIRED.
#
# It admitted a hard-coded set of counts (35 / 36 / 42 / 43 / 46), each via a
# witness row, and had to be widened by hand on every manifest addition. It
# was widened five times; the sixth addition arrived un-widened and reddened
# this suite for every unrelated cycle. A count-shaped predicate is, by
# docs/doc-invariant-registry.md §1-2, a cycle-scoped guard — it can never be
# a permanent invariant, and a cycle-scoped guard left live past its cycle is
# a defect. The durable property it was reaching for (the committed manifest
# matches its sources) is carried without any snapshot by the regenerate-and-
# compare checks: tests/test-issue-16-manifest-locale-invariance.sh AC2 and
# tests/plugin/verify-package.sh AC5d. AC-R3-a/b above are unaffected — they
# are state predicates over two named sources, not a count.
#
# Disposition recorded: docs/doc-invariant-registry.md §5.
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
# Capture-then-match (docs/submodule-common-rules.md:212, issues #964/#973,
# GATE:QUALITY E36/E37): each distinct (heading, file) pair captured once,
# reused across every check against it below.
ADR_CONFORMANCE_CTX="$(block_file 'ADR-conformance check' "$AUTOFLOW_GUIDE")"
assert_true "AC-961-1-b: ADR-conformance check subsection (GATE:PLAN) names both Feasibility and Scope" \
  "printf '%s\n' \"\$ADR_CONFORMANCE_CTX\" | grep -q 'Feasibility' && printf '%s\n' \"\$ADR_CONFORMANCE_CTX\" | grep -q 'Scope'"
assert_true "AC-961-1-c: ADR-conformance check subsection carries T-CAP verbatim ('caps the named item at 6'), window-scoped" \
  "printf '%s\n' \"\$ADR_CONFORMANCE_CTX\" | grep -qF 'caps the named item at 6'"
assert_true "AC-961-1-d: ADR-conformance check subsection carries T-TRIG-1 verbatim ('divergence from a governing ADR')" \
  "printf '%s\n' \"\$ADR_CONFORMANCE_CTX\" | grep -qF 'divergence from a governing ADR'"
assert_true "AC-961-1-e: ADR-conformance check subsection carries T-TRIG-2 verbatim ('architecture-impacting change with no governing ADR/owner decision')" \
  "printf '%s\n' \"\$ADR_CONFORMANCE_CTX\" | grep -qF 'architecture-impacting change with no governing ADR/owner decision'"
assert_true "AC-961-1-f: ADR-conformance check subsection carries T-NA verbatim ('N/A by default')" \
  "printf '%s\n' \"\$ADR_CONFORMANCE_CTX\" | grep -qF 'N/A by default'"
# Item-specific token (NOT the file-global T-CAP) — grep-confirmed absent
# pre-edit, so this attributes to the new insert rather than to landed prose.
KNOWN_BLINDSPOT_CTX="$(block_file 'Known blind-spot checks' "$AUTOFLOW_GUIDE")"
assert_true "AC-961-1-g: GATE:QUALITY blind-spot list carries item-specific 'caps Fit at 6'" \
  "printf '%s\n' \"\$KNOWN_BLINDSPOT_CTX\" | grep -qF 'caps Fit at 6'"
AGREEMENT_CRITERIA_CTX="$(block_file 'Agreement criteria' "$AUTOFLOW_GUIDE")"
assert_true "AC-961-1-h: ARCHITECT Agreement criteria carries T-NONSCORED verbatim ('a divergence is a COUNTER, not an ACCEPT')" \
  "printf '%s\n' \"\$AGREEMENT_CRITERIA_CTX\" | grep -qF 'a divergence is a COUNTER, not an ACCEPT'"

# =============================================================================
echo ""
echo "=== AC-961-2 — evaluation-system.md / teammate-contracts.md mirror, non-contradiction (feature AC4+AC5) ==="

RESPONSIBILITIES_CTX="$(block_file 'Responsibilities' "$TEAMMATE_CONTRACTS")"
assert_true "AC-961-2-c: teammate-contracts.md Facilitator Responsibilities names ADR conformance as a first-exchange axis" \
  "printf '%s\n' \"\$RESPONSIBILITIES_CTX\" | grep -qi 'ADR conformance'"

# Cross-doc invariant (the real drift risk per Phase B Approach 2): the cap
# surface named in evaluation-system.md string-matches the surface named in
# autoflow-guide.md — same three item names co-occur with the cap in both.
# Capture-then-match (SIGPIPE-safe form; same per-check independence as
# before the fix — each token still checked against the SAME captured row,
# not collapsed to a single-line co-occurrence regex, since that chained-AND
# structure is the existing, unchanged assertion this fix preserves).
GATE_PLAN_ROW_CTX="$(grep -E '^\| Plan evaluation \(GATE:PLAN\)' "$EVAL_SYSTEM")"
assert_true "AC-961-2-d: cross-doc cap-surface co-occurrence — evaluation-system.md GATE:PLAN row names Feasibility, Scope, and the cap value 6" \
  "printf '%s\n' \"\$GATE_PLAN_ROW_CTX\" | grep -q 'Feasibility' && printf '%s\n' \"\$GATE_PLAN_ROW_CTX\" | grep -q 'Scope' && printf '%s\n' \"\$GATE_PLAN_ROW_CTX\" | grep -qF '6'"
GATE_QUALITY_ROW_CTX="$(grep -E '^\| Quality evaluation \(GATE:QUALITY\)' "$EVAL_SYSTEM")"
assert_true "AC-961-2-e: cross-doc cap-surface co-occurrence — evaluation-system.md GATE:QUALITY row names Fit and the cap value 6" \
  "printf '%s\n' \"\$GATE_QUALITY_ROW_CTX\" | grep -q 'Fit' && printf '%s\n' \"\$GATE_QUALITY_ROW_CTX\" | grep -qF '6'"

# [MUST] intro reference-integrity assertion (Round-2 counter — feature §2 /
# verification §AC2). Appending a 4th blind-spot bullet under the unchanged
# intro breaks its hard count ('Three defect patterns ... caught only by
# external (Codex) review') — grep-confirmed present pre-edit at
# autoflow-guide.md:481, so its removal is a real RED->GREEN transition.
# Reuses KNOWN_BLINDSPOT_CTX captured above (static file content, safe to
# reuse across the whole run).
assert_false "AC-961-2-f: GATE:QUALITY blind-spot intro no longer hard-counts 'Three defect patterns'" \
  "printf '%s\n' \"\$KNOWN_BLINDSPOT_CTX\" | grep -qF 'Three defect patterns'"
assert_true "AC-961-2-g: GATE:QUALITY blind-spot section carries a distinct-provenance marker for the proactive ADR-0016 check (not a Codex catch)" \
  "printf '%s\n' \"\$KNOWN_BLINDSPOT_CTX\" | grep -qiE 'proactively-added|ADR-0016'"

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
