#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .claude/workflows/architect-deliberation.js .claude/workflows/verify-cause-branch.js .github/workflows/e2e-dummy-target.yml CLAUDE.md docs/autoflow-guide.md docs/submodule-common-rules.md docs/teammate-common-rules.md docs/teammate-contracts.md test/workflows/run.mjs
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
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
#   (retired #121)     — the diff-scoped manifest same-commit-regen guard and the
#                        bounded-deletion-run preservation audit this file used to
#                        carry were un-gated DELTAs over a merged cycle's own diff.
#                        Their dispositions and carriers are
#                        docs/doc-invariant-registry.md §16.
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
#   AC-C2-4            — no new assertion; the same-commit-regen obligation it
#                        relies on is carried in whole-tree state form by
#                        scripts/test/check-manifest-regen-clean.sh's FIXED POINT
#                        leg (both .js files are manifest sources).
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
#   AC-PRESERVE             — PASS pre-edit (nothing removed yet).
#
# CYCLE 2 RED expectation (pre-edit, this commit, per
# .autoflow/issue-955-c2-verification-design.md §4): all cycle-1 assertions
# above are already GREEN at this HEAD (cycle-1 landed in PR #958). The new
# cycle-2 discriminator, AC-C2-1 (token presence + non-comment clause count +
# both ledger-branch anchors), FAILs pre-edit — 0 matches for
# run_in_background/foreground/Bash Execution Mode in either workflow script.
# AC-C2-2 (suite reads both paths) PASSes as soon as this commit lands (files
# exist). AC-C2-1 tripwire (6/3 agent( sites, re-anchored issue #123) and G-REG
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
CI_WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"
ARCH_WF="$PROJECT_ROOT/.claude/workflows/architect-deliberation.js"
VERIFY_WF="$PROJECT_ROOT/.claude/workflows/verify-cause-branch.js"
RUN_MJS="$PROJECT_ROOT/test/workflows/run.mjs"

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

assert_true "AC1-a-canonical: canonical clause is [MUST] and names run_in_background" \
  "printf '%s' \"\$CANONICAL_JOINED\" | grep -qF '[MUST]' && printf '%s' \"\$CANONICAL_JOINED\" | grep -qF 'run_in_background'"
assert_true "AC1-a-canonical: canonical clause names foreground" \
  "printf '%s' \"\$CANONICAL_JOINED\" | grep -qF 'foreground'"
assert_true "AC1-a-canonical: canonical clause names teammate or subagent scope" \
  "printf '%s' \"\$CANONICAL_JOINED\" | grep -qE 'teammate|subagent'"

# =============================================================================
echo ""
echo "=== AC1-a-mirror (RED discriminator) — submodule-common-rules.md mirror clause ==="

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
# AC1-b and AC1-c are migrated to the registry by issue #120.
# =============================================================================
# AC1-b was a per-file conjunction over the five .claude/agents/autoflow-*.md
# role contracts; a registry entry holds one file and one predicate, so it
# decomposes into a `present` + `fixed` pair per file — ten entries,
# `120-955-agent-<role>-runinbackground` / `-foreground`. AC1-c was a
# whole-file `present` + regex over docs/teammate-contracts.md, carried by
# `120-955-contracts-inscript-agents`. Disposition recorded:
# docs/doc-invariant-registry.md §17.

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
# Re-anchored (issue #127): the floor is arithmetic on the MEASURED post-change line
# count, not on the agent( site tally below -- the two are not equal (8 sites, 9 clause
# lines: the ledger prompt's two-branch ternary carries the clause on each branch's own
# line). A floor derived from the site count (8) would be satisfied by the 7 pre-#127
# lines plus one new prompt, absorbing a second clause-less prompt unnoticed.
assert_true "AC-C2-1: architect-deliberation.js clause on >= 9 non-comment (prompt-literal) lines (re-anchored, issue #127 adds two agent() prompts, each carrying its own clause line)" \
  "[ \"$ARCH_CLAUSE_COUNT\" -ge 9 ]"
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
assert_true "AC-C2-1 tripwire: architect-deliberation.js has exactly 9 agent( call sites (re-anchored, issue #138 adds the Reconcile phase's 'ac-diff' comparison-channel call)" \
  "[ \"$ARCH_SITE_COUNT\" -eq 9 ]"
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
assert_true "AC-PRESERVE-d: CLAUDE.md Teammate-idle 'continue work when (a)/(b)/(c)' list retained" \
  "printf '%s' \"\$EXEC_PRINCIPLES_JOINED\" | grep -qF '(a) a teammate sends an actionable report' && printf '%s' \"\$EXEC_PRINCIPLES_JOINED\" | grep -qF '(c) the user types a new prompt'"


# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
