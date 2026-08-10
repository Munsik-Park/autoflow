#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: subagent run_in_background prohibition doc-assertion guard — Issue #955
# =============================================================================
# Tier-1 scripted assertion suite per verification design
# (.autoflow/issue-955-verification-design.md). Docs/ops change (no jest, no
# npm) — mirrors tests/test-issue-949-manifest-regen-doc.sh /
# tests/test-issue-800-doc-assertions.sh: assert_true/assert_false over
# grep/awk section extraction + git-diff + jq + comm.
#
# Placement (feature design §0, ratified branch): the canonical [MUST] clause
# lives in docs/teammate-common-rules.md (single-repo-correct "all teammates"
# home) and is mirrored verbatim in docs/submodule-common-rules.md (the
# issue's originally-named surface). This suite asserts the RATIFIED
# two-surface branch. If a later cycle reverts to the fallback
# (submodule-common-rules.md only), AC1-a-canonical and
# AC1-a-mirror-equality are dropped per the verification design's stated
# fallback note.
#
# Scope (verification design §1, Tier 1):
#   AC1-a-canonical    — RED discriminator: docs/teammate-common-rules.md
#                        carries a new "## Bash Execution Mode" section with a
#                        [MUST] clause naming run_in_background, foreground,
#                        and teammate/subagent.
#   AC1-a-mirror       — RED discriminator: docs/submodule-common-rules.md
#                        carries the mirrored "### Bash execution mode"
#                        subsection (under Testing Standards) with the same
#                        tokens plus a canonical cross-link to
#                        teammate-common-rules.md > Bash Execution Mode.
#   AC1-a-mirror-equality — guard: the canonical and mirror clause bodies are
#                        byte-identical for the normative sentence (mirror's
#                        cross-link line stripped before diff). Vacuously
#                        empty (PASS) pre-edit — neither body exists yet.
#   AC1-b              — RED discriminator: each of the five
#                        .claude/agents/autoflow-*.md files carries a
#                        Hard-rules bullet with run_in_background + foreground.
#   AC1-c              — RED discriminator: docs/teammate-contracts.md carries
#                        run_in_background + foreground + an in-script/
#                        workflows/* token (explicit facilitator-scope
#                        coverage, not left to transitive inheritance).
#   AC1-d              — RED discriminator: the same canonical phrase
#                        (run_in_background co-located with foreground within
#                        one clause) appears in all three doc surfaces
#                        (teammate-common-rules.md, submodule-common-rules.md,
#                        teammate-contracts.md) — one rule, placed thrice.
#   AC1-counterpart    — RED discriminator: CLAUDE.md Execution Principles
#                        states the background+idle-notification pattern is
#                        orchestrator/main-loop-only, justified by the
#                        future-turn lifecycle contract.
#   AC2                — RED discriminator: CLAUDE.md Teammate-idle-handling
#                        bullet is extended with the "Done + no report → shell
#                        verify, don't wait" direct-spawn reading.
#   AC3                — RED discriminator: docs/autoflow-guide.md REFINE AND
#                        VERIFY sections both carry a short-verification
#                        direct-/foreground-execution note.
#   AC4                — Green-state guard (949 precedent): the five manifest
#                        source files this cycle touches (teammate-common-
#                        rules.md, submodule-common-rules.md,
#                        teammate-contracts.md, CLAUDE.md, autoflow-guide.md)
#                        trigger a same-commit setup/manifest.json regen.
#                        Vacuously true pre-GREEN (empty diff intersection).
#   AC5-a/b/c          — RED discriminators: the canonical clause literally
#                        covers the reproducer — both entry paths (direct-spawn
#                        + in-script) named, the actor's OWN verification run
#                        named, and the clause is normatively [MUST].
#   CI registration    — RED discriminator: this suite is wired into
#                        .github/workflows/e2e-dummy-target.yml (both `paths:`
#                        trigger blocks + a `run:` step), #800/#949 precedent.
#   AC-PRESERVE        — guard: existing REFINE/VERIFY/Reporting-Format/idle
#                        content survives (no wholesale deletion).
#
# Cycle 2 (review-response, PR #958 Codex Medium Finding 1 — see
# .autoflow/issue-955-c2-verification-design.md / -c2-feature-design.md):
#   AC-C2-1            — RED discriminator: the 9 runtime-reachable prompt
#                        strings across .claude/workflows/architect-
#                        deliberation.js (6: dev-draft, test-draft, dev-r,
#                        test-r, both ledger ternary branches) and
#                        verify-cause-branch.js (3: test-self-check,
#                        impl-self-check, ledger) each carry
#                        run_in_background / foreground / the "Bash Execution
#                        Mode" pointer, ONLY on non-comment (prompt-literal)
#                        lines, with the two architect ledger branches
#                        independently anchor-bound (the clause must co-occur
#                        with the "ARCHITECT mutual ACCEPT" line AND with the
#                        "ARCHITECT non-convergence" line — a file-total or
#                        vicinity count is maldistribution-blind, DC-2). A
#                        structural agent( site-count tripwire (5 architect /
#                        3 verify) is kept as a change-detector, not the
#                        discriminator.
#   AC-C2-2            — RED discriminator: this suite reads both workflow
#                        scripts by absolute path (the AC-C2-1 assertions ARE
#                        this AC).
#   AC-C2-4            — no new assertion; the existing AC4 manifest-dogfood
#                        block already generalizes (both .js files are
#                        manifest sources).
#   G-REG              — Green-follow guard (NOT a RED discriminator):
#                        node test/workflows/run.mjs (CI job
#                        workflow-regression) must stay green; prompt edits
#                        are pure appends and must not perturb the pinned
#                        control-flow / substring assertions.
#
# Not in this file (verification design §2, manual residue):
#   AC5 semantic residue — "literally covers with no interpretation gap" is a
#     reading judgment the grep cannot fully settle; manual acceptance step.
#   E1 self-referential dispatch — orchestrator inspects its own dispatch
#     payload; no repo artifact to grep.
#
# RED expectation (pre-edit, this commit, per verification design §5): FAIL —
# AC1-a-canonical, AC1-a-mirror, AC1-a-mirror-equality(vacuous PASS, see
# below), AC1-b, AC1-c, AC1-d, AC1-counterpart, AC2, AC3, AC5-a, AC5-b, AC5-c,
# CI registration.
#
# JUSTIFIED PRE-EDIT PASSES (guards, NOT RED discriminators):
#   AC1-a-mirror-equality — vacuous PASS pre-edit (neither clause body exists
#     yet, so the diff of two empty bodies is empty).
#   AC4 (manifest dogfood) — vacuous PASS pre-edit (empty diff intersection).
#   AC-PRESERVE             — PASS pre-edit (nothing removed yet).
#
# CYCLE 2 RED expectation (pre-edit, this commit, per
# .autoflow/issue-955-c2-verification-design.md §4): all cycle-1 assertions
# above are already GREEN at this HEAD (cycle-1 landed in PR #958). The new
# cycle-2 discriminator, AC-C2-1 (token presence + non-comment clause count +
# both ledger-branch anchors), FAILs pre-edit — 0 matches for
# run_in_background/foreground/Bash Execution Mode in either workflow script.
# AC-C2-2 (suite reads both paths) PASSes as soon as this commit lands (files
# exist). AC-C2-1 tripwire (5/3 agent( sites) and G-REG
# (test/workflows/run.mjs exits 0) are guards that already PASS pre-edit and
# must stay green post-edit.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEAMMATE_COMMON="$PROJECT_ROOT/docs/teammate-common-rules.md"
SUBMODULE_COMMON="$PROJECT_ROOT/docs/submodule-common-rules.md"
TEAMMATE_CONTRACTS="$PROJECT_ROOT/docs/teammate-contracts.md"
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
GUIDE_MD="$PROJECT_ROOT/docs/autoflow-guide.md"
MANIFEST_JSON="$PROJECT_ROOT/setup/manifest.json"
CI_WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"
ARCH_WF="$PROJECT_ROOT/.claude/workflows/architect-deliberation.js"
VERIFY_WF="$PROJECT_ROOT/.claude/workflows/verify-cause-branch.js"
RUN_MJS="$PROJECT_ROOT/test/workflows/run.mjs"

AGENT_FILES=(
  "$PROJECT_ROOT/.claude/agents/autoflow-analyzer.md"
  "$PROJECT_ROOT/.claude/agents/autoflow-planner.md"
  "$PROJECT_ROOT/.claude/agents/autoflow-implementer.md"
  "$PROJECT_ROOT/.claude/agents/autoflow-tester.md"
  "$PROJECT_ROOT/.claude/agents/autoflow-evaluator.md"
)

# Base ref for scope-containment / mechanical-predicate diff guards
# (precedent: #797/#798/#799/#800/#949).
BASE_REF="${ISSUE_955_BASE_REF:-$(git -C "$PROJECT_ROOT" merge-base HEAD main 2>/dev/null || true)}"

CYCLE_DIFF_FILES=""
if [[ -n "$BASE_REF" ]]; then
  CYCLE_DIFF_FILES="$(git -C "$PROJECT_ROOT" diff --name-only "$BASE_REF"...HEAD 2>/dev/null || true)"
fi

PASS=0; FAIL=0; TESTS=0

# ---------------------------------------------------------------------------
# Helpers (assert_* pattern per tests/test-issue-949-manifest-regen-doc.sh)
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

skip_no_base() {
  local label="$1" count="${2:-1}"
  echo "  SKIP: $label (no base ref available)"
  TESTS=$((TESTS + count))
}

# ---------------------------------------------------------------------------
# Section extractors — scope discriminator greps to the exact target section
# (verification design: "Section-scoping: doc greps run against the extracted
# target section only, so an incidental match elsewhere cannot green a
# discriminator"). Stops at the next same-or-higher-level heading or a bare
# "---" separator.
# ---------------------------------------------------------------------------

extract_section() {
  local heading_pattern="$1" file="$2"
  awk -v p="$heading_pattern" '
    $0 ~ p { f=1; next }
    f && /^## / { f=0 }
    f && /^### / { f=0 }
    f && /^---$/ { f=0 }
    f { print }
  ' "$file"
}

CANONICAL_BODY="$(extract_section '^## Bash Execution Mode' "$TEAMMATE_COMMON")"
MIRROR_BODY="$(extract_section '^### Bash execution mode' "$SUBMODULE_COMMON")"
EXEC_PRINCIPLES_BODY="$(extract_section '^### Execution Principles' "$CLAUDE_MD")"
REFINE_BODY="$(extract_section '^## REFINE' "$GUIDE_MD")"
VERIFY_BODY="$(extract_section '^## VERIFY' "$GUIDE_MD")"

CANONICAL_JOINED="$(printf '%s' "$CANONICAL_BODY" | tr '\n' ' ')"
MIRROR_JOINED="$(printf '%s' "$MIRROR_BODY" | tr '\n' ' ')"
EXEC_PRINCIPLES_JOINED="$(printf '%s' "$EXEC_PRINCIPLES_BODY" | tr '\n' ' ')"
REFINE_JOINED="$(printf '%s' "$REFINE_BODY" | tr '\n' ' ')"
VERIFY_JOINED="$(printf '%s' "$VERIFY_BODY" | tr '\n' ' ')"

export CANONICAL_JOINED MIRROR_JOINED EXEC_PRINCIPLES_JOINED REFINE_JOINED VERIFY_JOINED

# =============================================================================
echo "=== AC1-a-canonical (RED discriminator) — teammate-common-rules.md canonical clause ==="

assert_true "AC1-a-canonical: '## Bash Execution Mode' section exists in docs/teammate-common-rules.md" \
  "grep -qF '## Bash Execution Mode' '$TEAMMATE_COMMON'"
assert_true "AC1-a-canonical: canonical clause is [MUST] and names run_in_background" \
  "printf '%s' \"\$CANONICAL_JOINED\" | grep -qF '[MUST]' && printf '%s' \"\$CANONICAL_JOINED\" | grep -qF 'run_in_background'"
assert_true "AC1-a-canonical: canonical clause names foreground" \
  "printf '%s' \"\$CANONICAL_JOINED\" | grep -qF 'foreground'"
assert_true "AC1-a-canonical: canonical clause names teammate or subagent scope" \
  "printf '%s' \"\$CANONICAL_JOINED\" | grep -qE 'teammate|subagent'"

# =============================================================================
echo ""
echo "=== AC1-a-mirror (RED discriminator) — submodule-common-rules.md mirror clause ==="

assert_true "AC1-a-mirror: '### Bash execution mode' subsection exists in docs/submodule-common-rules.md" \
  "grep -qF '### Bash execution mode' '$SUBMODULE_COMMON'"
assert_true "AC1-a-mirror: mirror clause names run_in_background + foreground" \
  "printf '%s' \"\$MIRROR_JOINED\" | grep -qF 'run_in_background' && printf '%s' \"\$MIRROR_JOINED\" | grep -qF 'foreground'"
assert_true "AC1-a-mirror: mirror clause cross-links the canonical home (teammate-common-rules.md > Bash Execution Mode)" \
  "printf '%s' \"\$MIRROR_JOINED\" | grep -qF 'teammate-common-rules.md' && printf '%s' \"\$MIRROR_JOINED\" | grep -qF 'Bash Execution Mode'"

# =============================================================================
echo ""
echo "=== AC1-a-mirror-equality (guard) — canonical and mirror normative bodies byte-identical ==="
# Strip the mirror's '> Canonical:' cross-link line before diffing (feature
# design: files 1 and 2 share the normative sentence verbatim; the mirror
# additionally carries a cross-link the canonical does not).

CANONICAL_NORMATIVE="$(printf '%s' "$CANONICAL_BODY" | grep -v '^\s*$')"
MIRROR_NORMATIVE="$(printf '%s' "$MIRROR_BODY" | grep -v '^\s*$' | grep -v '^> Canonical:')"
EQUALITY_DIFF="$(diff <(printf '%s\n' "$CANONICAL_NORMATIVE") <(printf '%s\n' "$MIRROR_NORMATIVE") 2>/dev/null || true)"

if [[ -z "$CANONICAL_NORMATIVE" && -z "$MIRROR_NORMATIVE" ]]; then
  echo "  PASS (vacuous): AC1-a-mirror-equality — neither clause body exists yet pre-edit"
  TESTS=$((TESTS + 1)); PASS=$((PASS + 1))
else
  assert_true "AC1-a-mirror-equality: canonical clause body and mirror clause body (cross-link stripped) are line-identical" \
    "[ -z \"\$EQUALITY_DIFF\" ]"
fi

# =============================================================================
echo ""
echo "=== AC1-b (RED discriminator) — five autoflow-*.md role contracts ==="

for f in "${AGENT_FILES[@]}"; do
  rel="${f#"$PROJECT_ROOT"/}"
  assert_true "AC1-b: $rel Hard-rules bullet names run_in_background + foreground" \
    "grep -qF 'run_in_background' '$f' && grep -qF 'foreground' '$f'"
done

# =============================================================================
echo ""
echo "=== AC1-c (RED discriminator) — teammate-contracts.md (incl. workflow in-script agents) ==="

assert_true "AC1-c: docs/teammate-contracts.md names run_in_background + foreground" \
  "grep -qF 'run_in_background' '$TEAMMATE_CONTRACTS' && grep -qF 'foreground' '$TEAMMATE_CONTRACTS'"
assert_true "AC1-c: docs/teammate-contracts.md explicitly names workflow in-script sub-agents (in-script / workflows/*)" \
  "grep -qE 'in-script|workflows/' '$TEAMMATE_CONTRACTS'"

# =============================================================================
echo ""
echo "=== AC1-d (RED discriminator) — uniform canonical phrase across all three doc surfaces ==="
# 'co-located within one clause' approximated as: run_in_background occurs
# with foreground appearing within the next 3 lines of the same file.

assert_true "AC1-d: docs/teammate-common-rules.md — run_in_background co-located with foreground" \
  "ctx=\$(grep -A3 -F 'run_in_background' '$TEAMMATE_COMMON'); printf '%s\n' \"\$ctx\" | grep -qF 'foreground'"
assert_true "AC1-d: docs/submodule-common-rules.md — run_in_background co-located with foreground" \
  "ctx=\$(grep -A3 -F 'run_in_background' '$SUBMODULE_COMMON'); printf '%s\n' \"\$ctx\" | grep -qF 'foreground'"
assert_true "AC1-d: docs/teammate-contracts.md — run_in_background co-located with foreground" \
  "ctx=\$(grep -A3 -F 'run_in_background' '$TEAMMATE_CONTRACTS'); printf '%s\n' \"\$ctx\" | grep -qF 'foreground'"

# =============================================================================
echo ""
echo "=== AC1-counterpart (RED discriminator) — CLAUDE.md background+idle is orchestrator-only ==="

assert_true "AC1-counterpart: Execution Principles states orchestrator/main-loop scope" \
  "printf '%s' \"\$EXEC_PRINCIPLES_JOINED\" | grep -qE 'orchestrator|main loop'"
assert_true "AC1-counterpart: Execution Principles names background" \
  "printf '%s' \"\$EXEC_PRINCIPLES_JOINED\" | grep -qF 'background'"
assert_true "AC1-counterpart: Execution Principles justifies via the future-turn lifecycle contract" \
  "printf '%s' \"\$EXEC_PRINCIPLES_JOINED\" | grep -qE 'future turn|lifetime|lifecycle'"

# =============================================================================
echo ""
echo "=== AC2 (RED discriminator) — CLAUDE.md idle-handling 'Done + no report' reading ==="

assert_true "AC2: Teammate idle handling carries a Done/completed token" \
  "printf '%s' \"\$EXEC_PRINCIPLES_JOINED\" | grep -qE 'Done|completed'"
assert_true "AC2: Teammate idle handling carries a shell-verification token" \
  "printf '%s' \"\$EXEC_PRINCIPLES_JOINED\" | grep -qE 'shell|\\.autoflow|artifact'"
assert_true "AC2: Teammate idle handling carries a do-not-wait token" \
  "printf '%s' \"\$EXEC_PRINCIPLES_JOINED\" | grep -qE 'do not wait|without waiting'"

# =============================================================================
echo ""
echo "=== AC3 (RED discriminator) — autoflow-guide.md REFINE + VERIFY direct-execution note ==="

assert_true "AC3: REFINE section carries a foreground/direct-execution token" \
  "printf '%s' \"\$REFINE_JOINED\" | grep -qE 'foreground|(directly.*orchestrator|orchestrator.*directly)'"
assert_true "AC3: VERIFY section carries a foreground/direct-execution token" \
  "printf '%s' \"\$VERIFY_JOINED\" | grep -qE 'foreground|(directly.*orchestrator|orchestrator.*directly)'"

# =============================================================================
echo ""
echo "=== AC4 (Green-state guard, conditional — NOT a RED discriminator) — manifest same-commit regen ==="
# 949 precedent: comm -12 <(cycle diff) <(manifest sources, self-excluded) is
# non-empty once any manifest-source doc is touched ⇒ setup/manifest.json
# MUST also be in the diff.

if [[ -z "$BASE_REF" ]]; then
  skip_no_base "AC4"
else
  AC4_INTERSECTION="$(comm -12 \
    <(git -C "$PROJECT_ROOT" diff --name-only "$BASE_REF"...HEAD 2>/dev/null | sort -u) \
    <(jq -r '.artifacts[].source' "$MANIFEST_JSON" 2>/dev/null | grep -vx 'setup/manifest.json' | sort -u) \
  )"
  echo "  intersection: $(printf '%s' "$AC4_INTERSECTION" | tr '\n' ' ')"
  if [[ -n "$AC4_INTERSECTION" ]]; then
    assert_true "AC4-DOGFOOD: diff-∩-sources non-empty ⇒ setup/manifest.json is itself in the diff" \
      "printf '%s\n' \"\$CYCLE_DIFF_FILES\" | grep -qxF 'setup/manifest.json'"
  else
    echo "  PASS (vacuous): AC4-DOGFOOD — diff-∩-sources is empty pre-GREEN, consequent not evaluated"
    TESTS=$((TESTS + 1)); PASS=$((PASS + 1))
  fi

  HEAD_SOURCES="$(jq -r '.artifacts[].source' "$MANIFEST_JSON" 2>/dev/null | sort -u)"
  BASE_SOURCES="$(git -C "$PROJECT_ROOT" show "$BASE_REF:setup/manifest.json" 2>/dev/null | jq -r '.artifacts[].source' 2>/dev/null | sort -u)"
  # #951 retired-guard disposition (docs/doc-invariant-registry.md, applied
  # per ledger E14/§DR-8): linking docs/doc-invariant-registry.md from
  # docs/INDEX.md deterministically enters it into the manifest's markdown
  # closure, so ONE additive source row for it is a hard requirement this
  # cycle (not a drift regression). AC4-CLOSURE is narrowed from "byte-
  # identical row set" to "identical, or the sole delta is that one additive
  # row" — a genuinely new/removed source elsewhere still FAILs.
  #
  # #979 lockstep update (ledger E12, GATE:PLAN PASS avg 9.0): the
  # reviewer-backend-selection delivery surface (feature design §4 rows 1-6)
  # adds six source rows on top of the #951 closure baseline -- three copy
  # rows (scripts/review/codex-review-pr.sh, scripts/preflight/check-review-
  # backend.sh, .codex/review.md), two scaffold rows (AGENTS.md,
  # .claude/autoflow.local.json), and docs/reviewer-backend.md via the same
  # markdown-link doc-closure mechanism as #951. AC4-CLOSURE additionally
  # admits this exact six-row addition set with zero removals -- any other
  # added/removed source still FAILs.
  #
  # #979 cycle-9 lockstep update (ledger E13): the GATE:PLAN-approved
  # reviewer-isolation design factors the reviewer-backend probe env scrub
  # into a shared lib, scripts/review/lib/claude-isolation.sh, delivered as
  # one additive source row on top of the six-row #979 closure set above
  # (six rows -> seven rows). AC4-CLOSURE additionally admits this exact
  # seven-row addition set with zero removals -- any other added/removed
  # source still FAILs.
  #
  # #25 lockstep update (ledger issue-25 E14, GATE:PLAN PASS): the
  # HANDOFF step-5 confirm-ci-green.sh helper is delivered as one
  # additive manifest source row, scripts/handoff/confirm-ci-green.sh,
  # on top of whatever closure set already sits at <base> (the #951/#979
  # rows above are already folded into main by the time this cycle
  # branched). AC4-CLOSURE additionally admits this single-row addition
  # with zero removals -- any other added/removed source still FAILs.
  #
  # #51 lockstep update (GATE:QUALITY E36): the teammate-removal
  # feasibility ADR is delivered as one additive manifest source row,
  # docs/adr/0017-teammate-removal-feasibility.md, via the same
  # docs/INDEX.md -> docs/adr/README.md markdown-link closure mechanism as
  # #951. AC4-CLOSURE additionally admits this single-row addition with
  # zero removals -- any other added/removed source still FAILs.
  #
  # #69 lockstep update: the verification-depth justification ADR is
  # delivered as one additive manifest source row,
  # docs/adr/0018-verification-depth-justification.md, via the same
  # docs/adr/README.md markdown-link closure mechanism as #51's 0017 row.
  # AC4-CLOSURE additionally admits this single-row addition with zero
  # removals -- any other added/removed source still FAILs.
  AC4_CLOSURE_ADDED="$(comm -13 <(printf '%s\n' "$BASE_SOURCES") <(printf '%s\n' "$HEAD_SOURCES"))"
  AC4_CLOSURE_REMOVED="$(comm -23 <(printf '%s\n' "$BASE_SOURCES") <(printf '%s\n' "$HEAD_SOURCES"))"
  AC979_CLOSURE_SET="$(printf '%s\n' \
    '.claude/autoflow.local.json' \
    '.codex/review.md' \
    'AGENTS.md' \
    'docs/reviewer-backend.md' \
    'scripts/preflight/check-review-backend.sh' \
    'scripts/review/codex-review-pr.sh' | sort -u)"
  AC979_C9_CLOSURE_SET="$(printf '%s\n' \
    '.claude/autoflow.local.json' \
    '.codex/review.md' \
    'AGENTS.md' \
    'docs/reviewer-backend.md' \
    'scripts/preflight/check-review-backend.sh' \
    'scripts/review/codex-review-pr.sh' \
    'scripts/review/lib/claude-isolation.sh' | sort -u)"
  assert_true "AC4-CLOSURE: manifest source-row set is identical at <base> and HEAD, or the only delta is the #951 docs/doc-invariant-registry.md manifest-closure row (§DR-8, ledger E14), is the #979 reviewer-backend-selection six-row delivery set (ledger E12), is the #979 cycle-9 seven-row delivery set (six-row set plus scripts/review/lib/claude-isolation.sh, ledger E13), is the #25 confirm-ci-green.sh single-row delivery set (ledger issue-25 E14), is the #51 docs/adr/0017-teammate-removal-feasibility.md single-row delivery set (GATE:QUALITY E36), or is the #69 docs/adr/0018-verification-depth-justification.md single-row delivery set" \
    "[ \"\$HEAD_SOURCES\" = \"\$BASE_SOURCES\" ] || { [ -z \"\$AC4_CLOSURE_REMOVED\" ] && [ \"\$AC4_CLOSURE_ADDED\" = 'docs/doc-invariant-registry.md' ]; } || { [ -z \"\$AC4_CLOSURE_REMOVED\" ] && [ \"\$AC4_CLOSURE_ADDED\" = \"\$AC979_CLOSURE_SET\" ]; } || { [ -z \"\$AC4_CLOSURE_REMOVED\" ] && [ \"\$AC4_CLOSURE_ADDED\" = \"\$AC979_C9_CLOSURE_SET\" ]; } || { [ -z \"\$AC4_CLOSURE_REMOVED\" ] && [ \"\$AC4_CLOSURE_ADDED\" = 'scripts/handoff/confirm-ci-green.sh' ]; } || { [ -z \"\$AC4_CLOSURE_REMOVED\" ] && [ \"\$AC4_CLOSURE_ADDED\" = 'docs/adr/0017-teammate-removal-feasibility.md' ]; } || { [ -z \"\$AC4_CLOSURE_REMOVED\" ] && [ \"\$AC4_CLOSURE_ADDED\" = 'docs/adr/0018-verification-depth-justification.md' ]; }"
fi

# =============================================================================
echo ""
echo "=== AC5-a/b/c (RED discriminators) — canonical clause literally covers the reproducer ==="

assert_true "AC5-a: canonical clause names BOTH direct-spawn (autoflow-*) AND in-script workflow agents" \
  "printf '%s' \"\$CANONICAL_JOINED\" | grep -qE 'autoflow-\\*|autoflow_' && printf '%s' \"\$CANONICAL_JOINED\" | grep -qE 'in-script|workflows/'"
assert_true "AC5-a: teammate-contracts.md run_in_background clause co-locates a direct-spawn actor token AND an in-script token (not a generic unrelated mention)" \
  "ctx=\$(grep -B2 -A2 -F 'run_in_background' '$TEAMMATE_CONTRACTS'); printf '%s\n' \"\$ctx\" | grep -qE 'autoflow-\\*|Developer-AI|Test AI|direct' && printf '%s\n' \"\$ctx\" | grep -qE 'in-script|workflows/'"
assert_true "AC5-b: canonical clause binds the actor's OWN verification command ('own'/'its own' co-located with 'verification')" \
  "printf '%s' \"\$CANONICAL_JOINED\" | grep -qE \"own\" && printf '%s' \"\$CANONICAL_JOINED\" | grep -qF 'verification'"
assert_true "AC5-c: canonical clause is normatively [MUST]" \
  "printf '%s' \"\$CANONICAL_JOINED\" | grep -qF '[MUST]'"

# =============================================================================
echo ""
echo "=== CI registration (RED discriminator) — suite wired into e2e-dummy-target.yml ==="

if [[ -f "$CI_WORKFLOW" ]]; then
  assert_true "CI-a: e2e-dummy-target.yml references test-issue-955-subagent-background-ban.sh" \
    "grep -q 'test-issue-955-subagent-background-ban' '$CI_WORKFLOW'"
  assert_true "CI-b: reference appears in a 'paths:' trigger block" \
    "ctx=\$(grep -B30 'test-issue-955-subagent-background-ban' '$CI_WORKFLOW'); printf '%s\n' \"\$ctx\" | grep -q '^ *paths:'"
  assert_true "CI-c: reference appears in a 'run:' step" \
    "ctx=\$(grep -A2 'test-issue-955-subagent-background-ban' '$CI_WORKFLOW'); printf '%s\n' \"\$ctx\" | grep -q 'run: bash tests/test-issue-955-subagent-background-ban.sh'"
else
  assert_true "CI-a: $CI_WORKFLOW exists" "false"
  echo "  SKIP: CI-b/c (workflow file missing)"
  TESTS=$((TESTS + 2))
fi

# =============================================================================
echo ""
echo "=== AC-C2-1 (RED discriminator) — workflow in-script agent prompts carry the foreground-only clause ==="
# Cycle-2 (PR #958 Codex Medium, Finding 1): the .claude/workflows/*.js
# in-script Developer-AI/Test-AI sub-agent prompts are the actual
# runtime-reachable instruction surface for a Workflow facilitation; the
# docs-only clause added in cycle 1 does not reach it. See
# .autoflow/issue-955-c2-verification-design.md.

for f in "$ARCH_WF" "$VERIFY_WF"; do
  rel="${f#"$PROJECT_ROOT"/}"
  assert_true "AC-C2-1: $rel names run_in_background" \
    "grep -qF 'run_in_background' '$f'"
  assert_true "AC-C2-1: $rel names foreground" \
    "grep -qF 'foreground' '$f'"
  assert_true "AC-C2-1: $rel names the Bash Execution Mode pointer" \
    "grep -qF 'Bash Execution Mode' '$f'"
done

# Placement guard (load-bearing) — the clause must live inside a prompt
# template-literal, not a `//`/`*` comment; count occurrences on non-comment
# lines only.
ARCH_CLAUSE_COUNT="$(grep -vE '^[[:space:]]*(//|\*)' "$ARCH_WF" | grep -cF 'run_in_background' || true)"
VERIFY_CLAUSE_COUNT="$(grep -vE '^[[:space:]]*(//|\*)' "$VERIFY_WF" | grep -cF 'run_in_background' || true)"
echo "  non-comment clause count: architect=$ARCH_CLAUSE_COUNT verify=$VERIFY_CLAUSE_COUNT"
assert_true "AC-C2-1: architect-deliberation.js clause on >= 6 non-comment (prompt-literal) lines" \
  "[ \"$ARCH_CLAUSE_COUNT\" -ge 6 ]"
assert_true "AC-C2-1: verify-cause-branch.js clause on >= 3 non-comment (prompt-literal) lines" \
  "[ \"$VERIFY_CLAUSE_COUNT\" -ge 3 ]"

# Per-branch anchor binding — both architect ledger ternary branches (L110
# converged / L111 non-converged) must independently carry the clause; a
# file-total or vicinity count is maldistribution-blind (round-1 devil's-
# advocate finding, DC-2): it would be satisfied by 2 occurrences on ONE
# branch + 0 on the other, leaving a whole runtime path uninstrumented.
assert_true "AC-C2-1: architect ledger CONVERGED branch (line carrying 'ARCHITECT mutual ACCEPT') carries the clause" \
  "grep -F 'ARCHITECT mutual ACCEPT' '$ARCH_WF' | grep -qF 'run_in_background'"
assert_true "AC-C2-1: architect ledger non-converged branch (line carrying 'ARCHITECT non-convergence') carries the clause" \
  "grep -F 'ARCHITECT non-convergence' '$ARCH_WF' | grep -qF 'run_in_background'"

# Structural site guard (tripwire, NOT the discriminator) — a future *added*
# agent( call site forces a re-derivation of the prompt-string count above.
ARCH_SITE_COUNT="$(grep -cF 'agent(' "$ARCH_WF" || true)"
VERIFY_SITE_COUNT="$(grep -cF 'agent(' "$VERIFY_WF" || true)"
assert_true "AC-C2-1 tripwire: architect-deliberation.js has exactly 5 agent( call sites" \
  "[ \"$ARCH_SITE_COUNT\" -eq 5 ]"
assert_true "AC-C2-1 tripwire: verify-cause-branch.js has exactly 3 agent( call sites" \
  "[ \"$VERIFY_SITE_COUNT\" -eq 3 ]"

# =============================================================================
echo ""
echo "=== AC-C2-2 (RED discriminator) — suite reads the two workflow scripts by absolute path ==="
# The AC-C2-1 assertions above ARE this AC: the suite now greps both workflow
# scripts directly (co-located with the agent( sites), which it did not do
# pre-cycle-2.
assert_true "AC-C2-2: suite variable ARCH_WF resolves to an existing file" "[ -f '$ARCH_WF' ]"
assert_true "AC-C2-2: suite variable VERIFY_WF resolves to an existing file" "[ -f '$VERIFY_WF' ]"

# =============================================================================
echo ""
echo "=== G-REG (Green-follow guard, NOT a RED discriminator) — test/workflows/run.mjs mock-runtime suite ==="
# Prompt-string edits are pure appends and must not perturb the control-flow
# lock this suite holds (convergence rule, ledger-authority branching, VERIFY
# next_action, arg guards) — c2 verification design §3 G-REG. Must stay green
# both pre-edit and post-edit.
if [[ -f "$RUN_MJS" ]]; then
  assert_true "G-REG: node test/workflows/run.mjs exits 0" \
    "node '$RUN_MJS' >/dev/null 2>&1"
else
  assert_true "G-REG: $RUN_MJS exists" "false"
fi


# =============================================================================
echo ""
echo "=== AC-PRESERVE (guard) — existing REFINE/VERIFY/Reporting-Format/idle content survives ==="

assert_true "AC-PRESERVE-a: REFINE existing [MUST] 'Re-run all tests' item retained" \
  "printf '%s' \"\$REFINE_JOINED\" | grep -qF '[MUST] Re-run all tests'"
assert_true "AC-PRESERVE-b: VERIFY existing cause-branch table (RED | GREEN | SEQUENTIAL_FIX | EVALUATION_AI) retained" \
  "printf '%s' \"\$VERIFY_JOINED\" | grep -qF 'SEQUENTIAL_FIX' && printf '%s' \"\$VERIFY_JOINED\" | grep -qF 'EVALUATION_AI'"
assert_true "AC-PRESERVE-c: submodule-common-rules.md Reporting Format items 1-6 retained" \
  "grep -qF '1. **Reference paths, not bodies**' '$SUBMODULE_COMMON' && grep -qF '6. **Facilitator return' '$SUBMODULE_COMMON'"
assert_true "AC-PRESERVE-d: CLAUDE.md Teammate-idle 'continue work when (a)/(b)/(c)' list retained" \
  "printf '%s' \"\$EXEC_PRINCIPLES_JOINED\" | grep -qF '(a) a teammate sends an actionable report' && printf '%s' \"\$EXEC_PRINCIPLES_JOINED\" | grep -qF '(c) the user types a new prompt'"

if [[ -z "$BASE_REF" ]]; then
  skip_no_base "AC-PRESERVE-deletion-audit"
else
  max_removed_run="$(git -C "$PROJECT_ROOT" diff "$BASE_REF"...HEAD -- "$TEAMMATE_COMMON" "$SUBMODULE_COMMON" "$TEAMMATE_CONTRACTS" "$CLAUDE_MD" "$GUIDE_MD" 2>/dev/null \
    | awk '/^-[^-]/{c++; if (c>m) m=c; next} {c=0} END{print m+0}')"
  assert_true "AC-PRESERVE-deletion-audit: no contiguous run >15 deleted lines across the five edited docs" \
    "[ \"${max_removed_run:-0}\" -le 15 ]"
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
