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
#   AC5  — manifest sha256 coherence oracle (#949 pattern)
#   G6   — doc reference-integrity on tests/test-sed-inplace.sh removal
#          (GATE:QUALITY doc_updates cap finding, cycle 2): decoupling-plan
#          row no longer a bare KEEP + retains a RETIRED marker (row
#          preserved for inventory history); improvement-backlog.md
#          setup-instantiation-1 entry carries a #952 resolution marker
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
#   AC5 manifest oracle — vacuously PASS pre-edit (no manifest source
#     touched yet in the diff); becomes load-bearing post-GREEN.
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
# Bounded run (issue #46): bare `timeout` is GNU coreutils and absent on stock
# macOS — exit 127 there replaces init.sh's usage line with `command not
# found`, a false AC1 FAIL. Reuse the repo's timeout/gtimeout + sleep-kill
# watchdog idiom (tests/test-issue-979-probe.sh run_bounded).
NOARG_TMP="$(mktemp -d)"
NOARG_LOG="$(mktemp)"
NOARG_TBIN=""
if command -v timeout >/dev/null 2>&1; then
  NOARG_TBIN="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  NOARG_TBIN="gtimeout"
fi
if [ -n "$NOARG_TBIN" ]; then
  (cd "$NOARG_TMP" && "$NOARG_TBIN" 5 bash "$INIT_SH" </dev/null) >"$NOARG_LOG" 2>&1
  NOARG_EXIT=$?
else
  set -m
  (cd "$NOARG_TMP" && bash "$INIT_SH" </dev/null) >"$NOARG_LOG" 2>&1 </dev/null &
  NOARG_PID=$!
  ( sleep 5; kill -TERM -"$NOARG_PID" 2>/dev/null || kill "$NOARG_PID" 2>/dev/null ) >/dev/null 2>&1 &
  NOARG_WPID=$!
  set +m
  wait "$NOARG_PID" 2>/dev/null
  NOARG_EXIT=$?
  kill -TERM -"$NOARG_WPID" 2>/dev/null || kill "$NOARG_WPID" 2>/dev/null
  wait "$NOARG_WPID" 2>/dev/null
fi
NOARG_OUT="$(cat "$NOARG_LOG")"
rm -rf "$NOARG_TMP" "$NOARG_LOG"

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
echo "=== G5 CI registration ==="

assert_true "G5: tests/test-issue-952-wizard-removal.sh referenced in e2e-dummy-target.yml run: step" \
  "grep -qF 'test-issue-952-wizard-removal.sh' '$CI_WORKFLOW'"
# SIGPIPE-safe capture-then-match (docs/submodule-common-rules.md > Testing Standards item
# 6, issues #964/#973): the prior direct `awk ... | grep -qF ...` piped a context-producing
# awk into a short-circuiting grep -qF under this script's own `set -uo pipefail` — when the
# match sits near the START of a long awk output (the push: block spans to EOF), grep exits
# before awk finishes writing, and the resulting SIGPIPE (awk exit 141) flips a logically-
# passing assertion to a flaky/deterministic FAIL (reproduced: consistently 141 for the push
# half here, GATE:QUALITY FAIL #4 investigation, unrelated to #56's own diff content).
pr_paths_ctx="$(awk '/^on:/{f=1} f && /pull_request:/{p=1} p && /^  push:/{exit} p' "$CI_WORKFLOW")"
assert_true "G5: e2e-dummy-target.yml pull_request paths: trigger lists this suite" \
  "printf '%s\n' \"\$pr_paths_ctx\" | grep -qF 'test-issue-952-wizard-removal.sh'"
push_paths_ctx="$(awk '/^  push:/{f=1} f' "$CI_WORKFLOW")"
assert_true "G5: e2e-dummy-target.yml push paths: trigger lists this suite" \
  "printf '%s\n' \"\$push_paths_ctx\" | grep -qF 'test-issue-952-wizard-removal.sh'"
# Capture-then-match (docs/submodule-common-rules.md:212, issues #964/#973):
# awk's buffered output piped directly into a short-circuiting `grep -q`
# consumer can SIGPIPE the producer under `set -o pipefail`. Capture each
# block once, then match the captured string.
assert_true "G5: e2e-dummy-target.yml pull_request paths: trigger lists this suite" \
  "ctx=\$(awk '/^on:/{f=1} f && /pull_request:/{p=1} p && /^  push:/{exit} p' '$CI_WORKFLOW'); printf '%s\n' \"\$ctx\" | grep -qF 'test-issue-952-wizard-removal.sh'"
assert_true "G5: e2e-dummy-target.yml push paths: trigger lists this suite" \
  "ctx=\$(awk '/^  push:/{f=1} f' '$CI_WORKFLOW'); printf '%s\n' \"\$ctx\" | grep -qF 'test-issue-952-wizard-removal.sh'"

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
