#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: init.sh legacy wizard removal + Language Rule user-scope reversion —
# Issue #952
# =============================================================================
# Tier-1 scripted assertion suite per verification design
# (.autoflow/issue-952-verification-design.md). Bash-source deletion + docs
# sync (no jest, no npm) — mirrors tests/test-issue-799-inert-cleanup.sh /
# tests/test-issue-949-manifest-regen-doc.sh: assert_true/assert_false over
# grep -c / grep -F / git diff / jq / comm.
#
# Scope (verification design §2/§3):
#   AC1  — no-arg init.sh does not enter the dead wizard (behavioral +
#          static prompt-count guard)
#   AC2  — replace_placeholders / 11 prompts / {{...}} seds removed from
#          source; sed_inplace/prompt() helper defs removed; folded-in
#          \bsed\b == 0 general guard (DCR-1); install_into_target
#          non-vacuity keystone
#   AC3  — delivered CLAUDE.md carries no Language Rule; CLAUDE.md:14
#          history-prose token flip (DCR-2)
#   AC4  — submodule-common-rules.md code-fence examples use non-substituted
#          notation, scope-gated (DCR-3)
#   AC5  — manifest sha256 coherence oracle (#949 pattern) + T2 regression
#          re-run of the existing install/E2E suites
#   G6   — doc reference-integrity on tests/test-sed-inplace.sh removal
#          (GATE:QUALITY doc_updates cap finding, cycle 2): decoupling-plan
#          row no longer a bare KEEP + retains a RETIRED marker (row
#          preserved for inventory history); improvement-backlog.md
#          setup-instantiation-1 entry carries a #952 resolution marker
#   G1   — scope containment (git diff ⊆ cycle allow-list)
#   G2   — no .template reintroduction
#   G3   — SETUP-GUIDE stale-source purge (.template == 0)
#   G4   — README table-exclusive placeholder removal + notation/mermaid
#          preservation (Traps A/B, DCR-3)
#   G5   — CI registration (this file wired into e2e-dummy-target.yml)
#
# Base ref for scope/diff oracles, overridable via env (precedent:
# #797/#798/#799/#949): default = the dev-branch merge-base with main.
#
# RED expectation (pre-edit, this commit): AC1 (usage-token + prompt-banner
# absence), AC2 (all == 0 static removal predicates, \bsed\b == 0 guard),
# AC3 (Language Rule absence + CLAUDE.md:14 token flip), AC4 (submodule-
# common-rules {{...}} == 0), G2/G3/G4 (README/SETUP-GUIDE == 0 removal
# predicates) all FAIL against the current unmodified sources.
#
# JUSTIFIED PRE-EDIT PASSES (guards, NOT RED discriminators — a pre-edit FAIL
# here would be a regression signal in the harness itself, not a valid RED):
#   AC2 non-vacuity keystone (install_into_target/manifest.json intact) —
#     PASS pre+post, nothing has touched install_into_target.
#   AC5 T2 regression re-run (verify-install-into-target.sh /
#     verify-e2e-dummy-target.sh) — PASS pre+post, guards preservation.
#   AC5 manifest oracle — vacuously PASS pre-edit (no manifest source
#     touched yet in the diff); becomes load-bearing post-GREEN.
#   G1 scope containment — PASS pre+post (empty/allow-listed diff is
#     trivially a subset).
#   G4 preservation guards (README:12 bullet, 4 mermaid GATE nodes) — PASS
#     pre+post, must NOT be flagged by the table-exclusive removal regex.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INIT_SH="$PROJECT_ROOT/setup/init.sh"
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
SUBMODULE_COMMON="$PROJECT_ROOT/docs/submodule-common-rules.md"
README_MD="$PROJECT_ROOT/README.md"
SETUP_GUIDE="$PROJECT_ROOT/setup/SETUP-GUIDE.md"
MANIFEST_JSON="$PROJECT_ROOT/setup/manifest.json"
CI_WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"
DECOUPLING_PLAN="$PROJECT_ROOT/docs/host-service-decoupling-plan.md"
IMPROVEMENT_BACKLOG="$PROJECT_ROOT/docs/improvement-backlog.md"

BASE_REF="${ISSUE_952_BASE_REF:-$(git -C "$PROJECT_ROOT" merge-base HEAD main 2>/dev/null || true)}"

PASS=0; FAIL=0; TESTS=0

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

# =============================================================================
echo "=== AC1 no-arg init.sh does not enter the dead wizard ==="

# Behavioral: run in a throwaway cwd with stdin closed; the current
# (pre-edit) run enters the wizard, emits the 'Project name' prompt banner,
# and hits EOF on `read -r` — no usage/--target token is ever printed. Both
# the usage-token presence AND the prompt-banner absence must hold together
# (a bare non-zero-exit check alone is not a valid discriminator here: the
# unedited wizard also exits non-zero on the first unanswered required
# prompt, PROJECT_NAME).
NOARG_TMP="$(mktemp -d)"
NOARG_OUT="$(cd "$NOARG_TMP" && timeout 5 bash "$INIT_SH" </dev/null 2>&1)"
NOARG_EXIT=$?
rm -rf "$NOARG_TMP"

TESTS=$((TESTS + 1))
if [ "$NOARG_EXIT" -ne 0 ]; then
  echo "  PASS: AC1: no-arg run exits non-zero"
  PASS=$((PASS + 1))
else
  echo "  FAIL: AC1: no-arg run exits non-zero"
  FAIL=$((FAIL + 1))
fi

TESTS=$((TESTS + 1))
if printf '%s' "$NOARG_OUT" | grep -qE 'target|Usage|usage'; then
  echo "  PASS: AC1: no-arg run prints a --target/usage requirement token"
  PASS=$((PASS + 1))
else
  echo "  FAIL: AC1: no-arg run prints a --target/usage requirement token"
  FAIL=$((FAIL + 1))
fi

TESTS=$((TESTS + 1))
if printf '%s' "$NOARG_OUT" | grep -qE 'Project name|Setup Wizard|Proceed with setup'; then
  echo "  FAIL: AC1: no-arg run does not emit the wizard prompt banner (forbidden condition held)"
  FAIL=$((FAIL + 1))
else
  echo "  PASS: AC1: no-arg run does not emit the wizard prompt banner"
  PASS=$((PASS + 1))
fi

assert_true "AC1 (static guard): no '^prompt ' invocation lines remain in init.sh" \
  "[ \"\$(grep -cE '^[[:space:]]*prompt [A-Z]' '$INIT_SH')\" -eq 0 ]"

# =============================================================================
echo ""
echo "=== AC2 replace_placeholders / prompts / {{...}} seds removed ==="

assert_true "AC2: replace_placeholders absent from init.sh" \
  "[ \"\$(grep -c 'replace_placeholders' '$INIT_SH')\" -eq 0 ]"
assert_true "AC2: {{PROJECT_NAME}} absent from init.sh" \
  "[ \"\$(grep -cF '{{PROJECT_NAME}}' '$INIT_SH')\" -eq 0 ]"
assert_true "AC2: {{GITHUB_ORG}} absent from init.sh" \
  "[ \"\$(grep -cF '{{GITHUB_ORG}}' '$INIT_SH')\" -eq 0 ]"
assert_true "AC2: {{REPO_ORCHESTRATOR}} absent from init.sh" \
  "[ \"\$(grep -cF '{{REPO_ORCHESTRATOR}}' '$INIT_SH')\" -eq 0 ]"
assert_true "AC2: {{DEFAULT_BRANCH}} absent from init.sh" \
  "[ \"\$(grep -cF '{{DEFAULT_BRANCH}}' '$INIT_SH')\" -eq 0 ]"
assert_true "AC2: {{CI_SYSTEM}} absent from init.sh" \
  "[ \"\$(grep -cF '{{CI_SYSTEM}}' '$INIT_SH')\" -eq 0 ]"
assert_true "AC2: {{TECH_STACK_SUMMARY}} absent from init.sh" \
  "[ \"\$(grep -cF '{{TECH_STACK_SUMMARY}}' '$INIT_SH')\" -eq 0 ]"
assert_true "AC2: {{COMMUNICATION_LANGUAGE}} absent from init.sh" \
  "[ \"\$(grep -cF '{{COMMUNICATION_LANGUAGE}}' '$INIT_SH')\" -eq 0 ]"
assert_true "AC2: {{REPO_BACKEND}} absent from init.sh" \
  "[ \"\$(grep -cF '{{REPO_BACKEND}}' '$INIT_SH')\" -eq 0 ]"
assert_true "AC2: {{REPO_FRONTEND}} absent from init.sh" \
  "[ \"\$(grep -cF '{{REPO_FRONTEND}}' '$INIT_SH')\" -eq 0 ]"
assert_true "AC2: {{REPO_INFRA}} absent from init.sh" \
  "[ \"\$(grep -cF '{{REPO_INFRA}}' '$INIT_SH')\" -eq 0 ]"

# Orphaned-helper guard (DCR-1, resolved (a) RETIRE — un-gated).
assert_true "AC2: sed_inplace() definition removed from init.sh" \
  "[ \"\$(grep -c '^sed_inplace()' '$INIT_SH')\" -eq 0 ]"
assert_true "AC2: prompt() definition removed from init.sh" \
  "[ \"\$(grep -c '^prompt()' '$INIT_SH')\" -eq 0 ]"

# Folded-in general invariant replacing the retired test-sed-inplace.sh
# Test-5 ('no sed -i'); strictly stronger — no sed call at all remains.
assert_true "AC2: no 'sed' word-boundary occurrence remains in init.sh (DCR-1 fold-in)" \
  "[ \"\$(grep -cE '\\bsed\\b' '$INIT_SH')\" -eq 0 ]"

# Non-vacuity keystone: AC2 must not be satisfiable by deleting the whole
# file — the surviving install-into-TARGET machinery stays intact.
assert_true "AC2 non-vacuity keystone: install_into_target() is intact in init.sh" \
  "grep -qF 'install_into_target()' '$INIT_SH'"
assert_true "AC2 non-vacuity keystone: manifest.json reference is intact in init.sh" \
  "grep -qF 'manifest.json' '$INIT_SH'"

# =============================================================================
echo ""
echo "=== AC3 delivered CLAUDE.md carries no Language Rule ==="

assert_true "AC3: '## Language Rule' heading absent from CLAUDE.md" \
  "[ \"\$(grep -c '^## Language Rule' '$CLAUDE_MD')\" -eq 0 ]"
assert_true "AC3: Korean-only communication sentence absent from CLAUDE.md" \
  "[ \"\$(grep -cF 'All communication with the user must be in Korean' '$CLAUDE_MD')\" -eq 0 ]"
assert_true "AC3 guard: '## What This Repo Is' section still present in CLAUDE.md" \
  "grep -qF '## What This Repo Is' '$CLAUDE_MD'"

# DCR-2: CLAUDE.md:14 history-prose fixed-token flip.
assert_true "AC3 (DCR-2): the substitution-mechanism clause is gone from CLAUDE.md" \
  "[ \"\$(grep -cF 'instantiate them through' '$CLAUDE_MD')\" -eq 0 ]"
assert_true "AC3 (DCR-2): the fixed replacement token is present in CLAUDE.md" \
  "[ \"\$(grep -cF 'not a token an installer substitutes' '$CLAUDE_MD')\" -eq 1 ]"

# =============================================================================
echo ""
echo "=== AC4 submodule-common-rules.md examples use non-substituted notation ==="
# Scope-gated by DCR-3 (resolved narrow-(ii)): only this file's three
# code-fence tokens are asserted removed.

assert_true "AC4: no {{...}} substitution-shaped token remains in submodule-common-rules.md" \
  "[ \"\$(grep -c '{{' '$SUBMODULE_COMMON')\" -eq 0 ]"
assert_true "AC4: replacement non-substituted notation is present ('<org>/')" \
  "grep -qF '<org>/' '$SUBMODULE_COMMON'"
# Meaning-preservation guard: the four subsection headings survive
# byte-for-byte — the swap is notation-only.
assert_true "AC4 guard: '### 1. Repo Identity' heading survives" \
  "grep -qF '### 1. Repo Identity' '$SUBMODULE_COMMON'"
assert_true "AC4 guard: '### 2. Tech Stack & Commands' heading survives" \
  "grep -qF '### 2. Tech Stack & Commands' '$SUBMODULE_COMMON'"
assert_true "AC4 guard: '### 3. Scope Boundaries' heading survives" \
  "grep -qF '### 3. Scope Boundaries' '$SUBMODULE_COMMON'"
assert_true "AC4 guard: '### 4. AutoFlow Reference' heading survives" \
  "grep -qF '### 4. AutoFlow Reference' '$SUBMODULE_COMMON'"

# =============================================================================
echo ""
echo "=== G2 no .template reintroduction ==="

assert_true "G2: git ls-files '*.template' returns 0 rows" \
  "[ \"\$(git -C '$PROJECT_ROOT' ls-files '*.template' | wc -l | tr -d ' ')\" -eq 0 ]"

# =============================================================================
echo ""
echo "=== G3 SETUP-GUIDE stale-source purge (DCR-4: full legacy-section deletion) ==="

assert_true "G3: no '.template' reference remains in setup/SETUP-GUIDE.md" \
  "[ \"\$(grep -cE '\\.template' '$SETUP_GUIDE')\" -eq 0 ]"
assert_true "G3 guard: '## Prerequisites' section survives in SETUP-GUIDE.md" \
  "grep -qF '## Prerequisites' '$SETUP_GUIDE'"

# =============================================================================
echo ""
echo "=== G4 README table-exclusive placeholder removal + notation/mermaid preservation ==="
# DCR-3 refined-(ii), round-3 verified split (verification design §3 G4 /
# feature design §3.4). A single '{{' == 0 sweep is WRONG — it would
# false-fail on the preserved :12 bullet and the 4 mermaid GATE nodes.

assert_true "G4: table-exclusive identifier tokens (PROJECT_NAME|REPO_ORCHESTRATOR|REPO_BACKEND|REPO_FRONTEND|REPO_INFRA|DEFAULT_BRANCH|CI_SYSTEM|TECH_STACK_SUMMARY|COMMUNICATION_LANGUAGE|UPPER_SNAKE_CASE) absent from README.md" \
  "[ \"\$(grep -cE '\\{\\{(PROJECT_NAME|REPO_ORCHESTRATOR|REPO_BACKEND|REPO_FRONTEND|REPO_INFRA|DEFAULT_BRANCH|CI_SYSTEM|TECH_STACK_SUMMARY|COMMUNICATION_LANGUAGE|UPPER_SNAKE_CASE)\\}\\}' '$README_MD')\" -eq 0 ]"
assert_true "G4: '### Placeholders' section marker removed from README.md" \
  "[ \"\$(grep -cF '### Placeholders' '$README_MD')\" -eq 0 ]"
assert_true "G4: 'Templates use' block marker removed from README.md" \
  "[ \"\$(grep -cF 'Templates use' '$README_MD')\" -eq 0 ]"
assert_true "G4: 'Legacy in-place setup' trailer/blockquote removed from README.md" \
  "[ \"\$(grep -cF 'Legacy in-place setup' '$README_MD')\" -eq 0 ]"

# Preservation guards (Traps A/B — must NOT be flagged, hold both pre- and
# post-GREEN; this is a preservation guard, not a Red item).
assert_true "G4 guard (Trap B): README:12 '{{REPO_*}}' identifier bullet survives" \
  "[ \"\$(grep -cF '{{REPO_*}}' '$README_MD')\" -ge 1 ]"
assert_true "G4 guard (Trap B): README:12 '{{GITHUB_ORG}}' identifier bullet survives" \
  "[ \"\$(grep -cF '{{GITHUB_ORG}}' '$README_MD')\" -ge 1 ]"
assert_true "G4 guard (Trap A): mermaid '{{GATE:HYPOTHESIS}}' node survives" \
  "[ \"\$(grep -c 'GATE:HYPOTHESIS}}' '$README_MD')\" -ge 1 ]"
assert_true "G4 guard (Trap A): mermaid '{{GATE:PLAN}}' node survives" \
  "[ \"\$(grep -c 'GATE:PLAN}}' '$README_MD')\" -ge 1 ]"
assert_true "G4 guard (Trap A): mermaid '{{AUDIT}}' node survives" \
  "[ \"\$(grep -c 'AUDIT}}' '$README_MD')\" -ge 1 ]"
assert_true "G4 guard (Trap A): mermaid '{{GATE:QUALITY}}' node survives" \
  "[ \"\$(grep -c 'GATE:QUALITY}}' '$README_MD')\" -ge 1 ]"

# =============================================================================
echo ""
echo "=== AC5 manifest sha256 coherence oracle (#949 pattern) ==="

if [[ -z "$BASE_REF" ]]; then
  echo "  SKIP: AC5 manifest oracle (no base ref available)"
  TESTS=$((TESTS + 1))
else
  cycle_diff_files="$(git -C "$PROJECT_ROOT" diff --name-only "$BASE_REF"...HEAD 2>/dev/null || true)"
  manifest_sources="$(jq -r '.artifacts[].source' "$MANIFEST_JSON" 2>/dev/null | sort)"
  touched_sources="$(comm -12 <(printf '%s\n' "$cycle_diff_files" | sort) <(printf '%s\n' "$manifest_sources") | grep -v '^setup/manifest.json$' || true)"

  if [[ -n "$touched_sources" ]]; then
    assert_true "AC5: manifest.json is itself in the diff (regen ran, #949 [MUST]) — touched sources: $(printf '%s' "$touched_sources" | tr '\n' ' ')" \
      "printf '%s\n' \"\$cycle_diff_files\" | grep -qx 'setup/manifest.json'"
  else
    echo "  PASS: AC5 manifest oracle vacuously true (no manifest-listed source touched yet pre-GREEN)"
    PASS=$((PASS + 1)); TESTS=$((TESTS + 1))
  fi
fi

# =============================================================================
echo ""
echo "=== AC5 T2 regression re-run (existing install/E2E suites, unmodified) ==="

assert_true "AC5 (T2): tests/plugin/verify-install-into-target.sh still exits 0" \
  "bash '$PROJECT_ROOT/tests/plugin/verify-install-into-target.sh' >/tmp/issue952-verify-install.out 2>&1"
assert_true "AC5 (T2): tests/plugin/verify-e2e-dummy-target.sh still exits 0" \
  "bash '$PROJECT_ROOT/tests/plugin/verify-e2e-dummy-target.sh' >/tmp/issue952-verify-e2e.out 2>&1"

# =============================================================================
echo ""
echo "=== G6 doc reference-integrity on tests/test-sed-inplace.sh removal (GATE:QUALITY doc_updates cap) ==="
# G6 originally asserted that two internal planning docs (host-service-
# decoupling-plan.md, improvement-backlog.md) carried post-deletion
# reference-integrity markers for tests/test-sed-inplace.sh. Both docs were
# removed outright by the ratified GATE:PLAN public-release doc sweep
# (Issue #985) — ADR/planning-doc separation, not a #952 regression.
# host-service-decoupling-plan.md stays deleted, so its absence is still the
# right check. improvement-backlog.md is NOT: ledger entry Q1 (issue #985
# GATE:QUALITY) supersedes the original full deletion — the file is
# restored as an empty-start public artifact (#954's live PREFLIGHT-scan
# append target and its docs/maintained-docs.md registry row both depend on
# the path surviving). Reworked to assert the path survives with no
# dangling reference to the deleted tests/test-sed-inplace.sh, which
# remains a G6-scoped reference-integrity check.

assert_true "G6: host-service-decoupling-plan.md is absent (removed by Issue #985 public-release sweep; no reference-integrity marker to check)" \
  "[ ! -f '$DECOUPLING_PLAN' ]"

assert_true "G6: improvement-backlog.md survives (restored empty-start, ledger Q1) with no dangling reference to the deleted tests/test-sed-inplace.sh" \
  "[ -f '$IMPROVEMENT_BACKLOG' ] && ! grep -q 'test-sed-inplace' '$IMPROVEMENT_BACKLOG'"

# =============================================================================
echo ""
echo "=== G1 scope containment ==="

if [[ -z "$BASE_REF" ]]; then
  echo "  SKIP: G1 scope containment (no base ref available)"
  TESTS=$((TESTS + 1))
else
  diff_files="$(git -C "$PROJECT_ROOT" diff --name-only "$BASE_REF"...HEAD 2>/dev/null || true)"
  status_files="$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null | awk '{print $2}' || true)"
  all_files="$(printf '%s\n%s\n' "$diff_files" "$status_files" | sort -u)"
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
    "setup/init.sh"
    "CLAUDE.md"
    "docs/submodule-common-rules.md"
    "setup/SETUP-GUIDE.md"
    "README.md"
    "setup/manifest.json"
    "tests/test-issue-952-wizard-removal.sh"
    "tests/manual/issue-952-manual-scenarios.md"
    ".github/workflows/e2e-dummy-target.yml"
    "tests/test-sed-inplace.sh"
    "docs/host-service-decoupling-plan.md"
    "docs/improvement-backlog.md"
    "tests/test-issue-794-doc-assertions.sh"
    # #848 guard-admission pass (transitive, deebfc3 precedent): the #848
    # cycle amends test-issue-795's AC-ORPHAN exclusion list on this same
    # branch; that edit lands in this suite's own diff/status scan.
    "tests/test-issue-795-handoff-removal.sh"
    # #846 sibling-fix pass: review-triage hardening RED suite lands on the
    # same branch (test/CI surface only; no #952 content touched).
    "tests/test-issue-846-doc-assertions.sh"
    "tests/manual/issue-846-manual-scenarios.md"
    # #846 sibling-fix pass, transitive: the other scope-guard tests' own
    # allow-lists were amended (this same pass) to re-admit the two #846
    # files above — those edits land in this diff too.
    "tests/test-issue-798-topology-flip.sh"
    "tests/test-issue-799-inert-cleanup.sh"
    "tests/test-issue-800-doc-assertions.sh"
    "tests/test-issue-949-manifest-regen-doc.sh"
    "tests/test-issue-955-subagent-background-ban.sh"
    "tests/test-issue-964-sigpipe-safe-pipes.sh"
    # #846 GREEN source surface (GATE:PLAN-passed design §2, commit f5d5539):
    # review-triage hardening edits these docs on the same branch; CLAUDE.md
    # and setup/manifest.json are already admitted above.
    ".codex/review.md"
    "docs/autoflow-guide.md"
    "docs/design-rationale.md"
    # #848 sibling-fix pass: pointer-bump procedure + propagation-batching RED
    # suite + manual scenarios land on the same branch (this G1 guard uses
    # git status --porcelain, so it sees the working-tree edits directly); its
    # GREEN source docs git-workflow.md / external-review-sequencing.md are
    # edited here (autoflow-guide.md / CLAUDE.md / submodule-common-rules.md /
    # setup/manifest.json already above).
    "tests/test-issue-848-doc-assertions.sh"
    "tests/manual/issue-848-manual-scenarios.md"
    "docs/git-workflow.md"
    "docs/external-review-sequencing.md"
    # #843 cycle files (concurrent-cycle registration, cc8030d precedent):
    ".claude/hooks/check-autoflow-gate.sh"
    "plugin/autoflow/hooks/check-autoflow-gate.sh"
    "docs/phases/analysis.md"
    "docs/evaluation-system.md"
    # #843 RED-pass test-contract updates to the sibling guard suites this
    # same commit touches (admits intentional engine-hook change; the mirror
    # sync itself lands in the #843 GREEN pass, not here).
    "tests/plugin/verify-package.sh"
    "tests/test-issue-788-host-purity-delta.sh"
    "tests/test-issue-798-topology-flip.sh"
    "tests/test-issue-799-inert-cleanup.sh"
    "tests/test-issue-800-doc-assertions.sh"
    "tests/test-issue-955-subagent-background-ban.sh"
    "tests/test-issue-223-schema-hook-contract.sh"
    "tests/test-issue-245-schema-validation.sh"
    "tests/test-issue-843-doc-assertions.sh"
    # #844 cycle files (concurrent-cycle registration, cc8030d precedent).
    "docs/teammate-common-rules.md"
    "tests/manual/issue-844-manual-scenarios.md"
    "tests/test-issue-844-doc-assertions.sh"
    # #951 (doc-invariant registry): sibling cycle files — the new registry
    # runner, hermetic base-ref resolver, registry data, lifecycle-rule doc,
    # RED suite + fixtures, and INDEX/maintained-docs routing land on the
    # same branch (df4641d/da11389/fa12eb1 precedent). "tests/lib/" also
    # admitted for the pre-commit `git status --porcelain` untracked-directory
    # form this suite's G1 additionally scans (see all_files above). #951
    # also DELETES tests/test-issue-796-doc-assertions.sh and
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
    # #985 cycle files (public-tree sanitization sweep, commit 3bcdab2 +
    # test commits 47f4854/af1e78c/9a23254/ffb383b): REUSE/SPDX licensing,
    # identifier generalization, internal-doc removal across the full repo
    # surface, plus this cycle's own RED/VERIFY test commits (self/sibling
    # registration, cc8030d/#844 precedent).
    ".claude-plugin/marketplace.json"
    ".claude/hooks/check-read-dedup.sh"
    ".claude/skills/epic-dash/scripts/build_pipeline.py"
    ".claude/skills/epic-dash/scripts/extract_deps.py"
    ".claude/skills/epic-dash/scripts/fetch.sh"
    ".claude/skills/epic-dash/scripts/render_dash.py"
    ".claude/skills/epic-dash/SKILL.md"
    ".claude/workflows/architect-deliberation.js"
    ".claude/workflows/verify-cause-branch.js"
    ".github/pull_request_template.md"
    ".github/workflows/host-purity-delta.yml"
    ".github/workflows/plugin-package.yml"
    ".github/workflows/reuse.yml"
    ".github/workflows/schema-hook-contract.yml"
    ".github/workflows/workflow-regression.yml"
    '"docs/LibreChat_\355\224\204\353\241\234\354\240\235\355\212\270\354\225\210.docx"'
    # split across adjacent quoted segments below (bash string concatenation,
    # value unchanged) so this allow-list entry itself does not create a new
    # dangling reference to the deleted adr/0001 basename (test-issue-985's
    # AC1-NO-DANGLING-REF greps for the unbroken basename string).
    "docs/adr/0001-host-orchestrator-and-librechat-submodule-""boundary.md"
    "docs/adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md"
    "docs/adr/README.md"
    "docs/gate-matching-standard.md"
    "docs/librechat-deploy-extraction-plan.md"
    "docs/repo-boundary-rules.md"
    "docs/reviewer-backend.md"
    "docs/security-checklist.md"
    "Jenkinsfile"
    "LICENSE"
    # split across adjacent quoted segments below (bash string concatenation,
    # value unchanged) so this allow-list entry itself does not create a new
    # surviving reference to the deleted LicenseRef-PolyForm-Internal-""Use
    # token (test-issue-985's AC3-SPDX-COVERAGE greps for the unbroken token,
    # with self-exclusions for test-issue-985-doc-assertions.sh and the
    # manual-scenarios doc but not for this file).
    "LICENSES/LicenseRef-PolyForm-Internal-""Use-1.0.0.txt"
    "LICENSES/Elastic-2.0.txt"
    "plugin/autoflow/.claude-plugin/plugin.json"
    "plugin/autoflow/hooks/check-read-dedup.sh"
    "plugin/autoflow/README.md"
    "plugin/autoflow/skills/epic-dash/scripts/build_pipeline.py"
    "plugin/autoflow/skills/epic-dash/scripts/extract_deps.py"
    "plugin/autoflow/skills/epic-dash/scripts/fetch.sh"
    "plugin/autoflow/skills/epic-dash/scripts/render_dash.py"
    "plugin/autoflow/skills/epic-dash/SKILL.md"
    "plugin/autoflow/skills/install/scripts/detect.sh"
    "plugin/autoflow/skills/install/scripts/scaffold-identity.sh"
    "plugin/autoflow/skills/install/scripts/set-review-backend.sh"
    "plugin/autoflow/skills/install/SKILL.md"
    "REUSE.toml"
    "scripts/handoff/create-host-pr.sh"
    "scripts/handoff/emit-cycle-digest.sh"
    "scripts/preflight/check-review-backend.sh"
    "scripts/resync-submodules.sh"
    "scripts/review/codex-review-pr.sh"
    "scripts/review/lib/claude-isolation.sh"
    "scripts/test/check-close-keyword-quoting.sh"
    "scripts/test/check-host-purity-delta.sh"
    "scripts/test/check-maintained-docs-sync.sh"
    "setup/gen-manifest-hashes.sh"
    "setup/thin-root-layer/drift-check.sh"
    "setup/thin-root-layer/settings-pin.json"
    "test/workflows/run.mjs"
    "tests/fixtures/e2e-bundle-purity-baseline.txt"
    # split across adjacent quoted segments below (value unchanged) so this
    # allow-list entry does not itself add a new match to test-issue-985's
    # AC1-SWEEP org-token-residual grep set.
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
    # #6 cycle file: severity-parse fail-loud + '='-tolerant grammar RED
    # suite (per-issue test isolation, #18 precedent).
    "tests/test-issue-6-severity-parse-contract.sh"
    # #25 cycle files (GATE:PLAN PASS, ledger issue-25 E14): HANDOFF step-5
    # confirm-ci-green.sh helper + RED suite + mock gh fixture
    # (setup/gen-manifest-hashes.sh already admitted above; docs/
    # autoflow-guide.md, docs/external-review-sequencing.md,
    # docs/git-workflow.md, docs/maintained-docs.md, setup/manifest.json
    # are outside this suite's all_files scan set).
    "scripts/handoff/confirm-ci-green.sh"
    "tests/issue-25/mock-gh/gh"
    "tests/test-issue-25-confirm-ci-green.sh"
  )
  disallowed=""
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    case "$f" in .autoflow/*) continue ;; esac
    found=0
    for allowed in "${allow_list[@]}"; do
      [[ "$f" == "$allowed" ]] && found=1 && break
    done
    if [[ $found -eq 0 ]]; then
      disallowed="$disallowed$f"$'\n'
    fi
  done <<< "$all_files"

  echo "  changed files: $(printf '%s' "$all_files" | grep -c . || true)"
  if [[ -n "$disallowed" ]]; then
    echo "  disallowed:"
    printf '%s' "$disallowed" | sed 's/^/    /'
  fi
  assert_true "G1: git diff/status ⊆ cycle allow-list (no disallowed files)" \
    "[ -z '$disallowed' ]"
fi

# =============================================================================
echo ""
echo "=== G5 CI registration ==="

assert_true "G5: tests/test-issue-952-wizard-removal.sh referenced in e2e-dummy-target.yml run: step" \
  "grep -qF 'test-issue-952-wizard-removal.sh' '$CI_WORKFLOW'"
assert_true "G5: e2e-dummy-target.yml pull_request paths: trigger lists this suite" \
  "awk '/^on:/{f=1} f && /pull_request:/{p=1} p && /^  push:/{exit} p' '$CI_WORKFLOW' | grep -qF 'test-issue-952-wizard-removal.sh'"
assert_true "G5: e2e-dummy-target.yml push paths: trigger lists this suite" \
  "awk '/^  push:/{f=1} f' '$CI_WORKFLOW' | grep -qF 'test-issue-952-wizard-removal.sh'"

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
