#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: public-release tree sanitization — identifier sweep, internal-doc
#       separation, LICENSE/SPDX/REUSE (Issue #985 [chore · #984-S1])
# =============================================================================
# Tier-1 scripted assertion suite per verification design
# (.autoflow/issue-985-verification-design.md Part 2/Part 5). Docs/config/
# tree-shape change (no package.json / jest in this repo) — mirrors the
# established bash doc-assertion convention (assert_true/assert_false over
# grep + git ls-files, canonical `Results: P/T passed, F failed` line,
# exit 1 iff F>0; precedent tests/test-issue-848-doc-assertions.sh, -846,
# -800).
#
# AC -> discriminator map (verification design Part 2/Part 5):
#   AC1 - connev identifiers/domains/internal-docs removed or generalized:
#     AC1-SWEEP               RED - git grep -il connev match set equals the
#                             checked-in tests/fixtures/expected-connev-residual.txt
#                             allowlist exactly (D7: the three-file host-purity
#                             denylist set plus the two issue-985 test artifacts
#                             that legitimately describe the sweep — five files
#                             total; VERIFY cause-branch correction).
#     AC1-DOMAIN              RED - git grep -il 'connev\.io' outside the
#                             host-purity fixture set (L4) returns empty.
#     AC1-INTERNAL-DOCS-ABSENT RED - each removed path is absent from
#                             git ls-files.
#     AC1-DIGEST-EMPTIED      RED - docs/cycle-digest.jsonl has 0 lines
#                             (public tree starts empty; path preserved - D4).
#     AC1-NO-DANGLING-REF     RED - no surviving tracked file references the
#                             adr/0001 basename once it is deleted (known
#                             inbound refs per feature design Part 7/W4).
#   AC2 - plugin key autoflow@autoflow consistent + drift-check green:
#     AC2-KEY-CONSISTENT      RED - git grep -F 'autoflow@claude-autoflow'
#                             returns empty (every occurrence in the rename
#                             chain reads autoflow@autoflow / Munsik-Park/autoflow).
#   AC3 - reuse lint PASS + 6 GitHub Actions workflows green:
#     AC3-SPDX-COVERAGE       RED - every header-bearing tracked source
#                             (.sh/.py/.bats/.yml/.js/.mjs, enumerated from
#                             the current tree per verification design
#                             ROUND-1 correction) carries both SPDX lines
# REUSE-IgnoreStart
#                             (SPDX-License-Identifier: Elastic-2.0 per the
# REUSE-IgnoreEnd
#                             2026-07-10 owner decision superseding PolyForm
#                             Internal Use 1.0.0); REUSE.toml +
#                             LICENSES/Elastic-2.0.txt exist (Elastic-2.0 is
#                             SPDX-listed - no LicenseRef file); no surviving
#                             LicenseRef-PolyForm-Internal-Use-1.0.0 token
#                             remains anywhere tracked.
#     AC3-WORKFLOW-COUNT      RED - .github/workflows/ count is 6 (5 existing
#                             + reuse.yml), existing 5 filenames unchanged.
#   AC4 - public README is a single plugin-install narrative:
#     AC4-INSTALL-PATH        RED - README contains
#                             '/plugin marketplace add Munsik-Park/autoflow' and
#                             does not contain 'connev-llm'.
#     AC4-LICENSE-SUMMARY     RED - README contains an Elastic License 2.0
#                             allow/deny summary section + the one-line
#                             commercial-exception notice.
#   Implicit AC (work-item Sec.3, 2026-07-10 owner decision) - LICENSE /
#   LICENSES/ file (Elastic License 2.0, superseding PolyForm Internal Use):
#     AC-LICENSE              RED - LICENSE carries the Elastic License 2.0
#                             text (not MIT, not PolyForm) + Copyright (c)
#                             2026 Munsik-Park; LICENSES/Elastic-2.0.txt
#                             exists; LICENSES/LicenseRef-PolyForm-Internal-Use-1.0.0.txt
#                             is absent.
#
# Not in this file (verification design Part 3/Part 4 - env-dependent /
# manual, out of this RED spawn's automated scope):
#   AC3-REUSE-LINT   (env-dependent: reuse not installed locally)   - CI/HANDOFF
#   AC3-CI-GREEN     (env-dependent: observed on GitHub Actions)    - HANDOFF
#   AC4-NARRATIVE    (manual: narrative coherence)                  - Part 3 #1
#   reuse lint real run                                             - Part 3 #5
#
# EXCEPTION (per RED contract): the verification design's Part 1/Part 5
# lockstep-guard suites (run-doc-invariants.sh, drift-check.sh,
# verify-install-into-target.sh, verify-thin-root-layer.sh,
# verify-e2e-dummy-target.sh, verify-package.sh, verify-install-skill-scripts.sh,
# test-codex-review-label-step.sh, test-issue-788-host-purity-delta.sh) are
# EXISTING suites that currently PASS and must STAY green after the sweep
# lands the fixture updates in lockstep - they are not re-authored here and
# are not expected to be Red now.
#
# RED expectation (pre-implementation, this commit): AC1-SWEEP, AC1-DOMAIN,
# AC1-INTERNAL-DOCS-ABSENT, AC1-DIGEST-EMPTIED, AC1-NO-DANGLING-REF,
# AC2-KEY-CONSISTENT, AC3-SPDX-COVERAGE, AC3-WORKFLOW-COUNT, AC4-INSTALL-PATH,
# AC4-LICENSE-SUMMARY, AC-LICENSE all FAIL (target artifacts/tokens absent
# from current HEAD; verified this session against the design branch tree).
#
# Harness convention: set -uo pipefail, assert_true/assert_false, canonical
# `Results: P/T passed, F failed` line, exit 1 iff F>0.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

README="$PROJECT_ROOT/README.md"
LICENSE_FILE="$PROJECT_ROOT/LICENSE"
LICENSES_DIR="$PROJECT_ROOT/LICENSES"
REUSE_TOML="$PROJECT_ROOT/REUSE.toml"
EXPECTED_RESIDUAL="$PROJECT_ROOT/tests/fixtures/expected-connev-residual.txt"
CYCLE_DIGEST="$PROJECT_ROOT/docs/cycle-digest.jsonl"
WORKFLOWS_DIR="$PROJECT_ROOT/.github/workflows"

PASS=0; FAIL=0; TESTS=0

# ---------------------------------------------------------------------------
# Helpers (assert_* pattern per tests/test-issue-848-doc-assertions.sh /
# tests/test-issue-800-doc-assertions.sh)
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

echo "=== Issue #985 doc-assertions ==="

# =============================================================================
echo ""
echo "=== AC1 — connev identifier/domain/internal-doc sweep ==="

# AC1-SWEEP: the expected-residual allowlist must exist (D7) and the live
# git grep -il connev match set must equal it exactly.
assert_true "AC1-SWEEP: tests/fixtures/expected-connev-residual.txt exists" \
  "[ -f '$EXPECTED_RESIDUAL' ]"

if [ -f "$EXPECTED_RESIDUAL" ]; then
  actual_matches="$(cd "$PROJECT_ROOT" && git grep -il connev | sort)"
  expected_matches="$(sort "$EXPECTED_RESIDUAL")"
  assert_true "AC1-SWEEP: git grep -il connev match set equals expected-connev-residual.txt exactly" \
    "[ \"\$(git grep -il connev | sort)\" = \"\$(sort '$EXPECTED_RESIDUAL')\" ]"
else
  echo "  SKIP: AC1-SWEEP set-equality (allowlist file missing)"
  TESTS=$((TESTS + 1)); FAIL=$((FAIL + 1))
  echo "  FAIL: AC1-SWEEP: git grep -il connev match set equals expected-connev-residual.txt exactly"
fi

# AC1-DOMAIN: connev.io outside the host-purity fixture set (L4) is empty.
# NOTE (VERIFY cause-branch correction): tests/fixtures/host-purity-tokens.txt
# stores the token ERE-escaped as `connev\.io` (a literal backslash-dot in the
# file text), which `git grep -il 'connev\.io'` — a BRE where `\.` matches a
# literal `.` — can never match; it is intentionally excluded from this
# expected set. This suite's own AC1-SWEEP doc comment above (plain
# `connev.io`) does match the grep and is included instead.
assert_true "AC1-DOMAIN: 'connev\\.io' appears only in the host-purity denylist fixture set (L4) plus this suite's own doc comment" \
  "diff <(git grep -il 'connev\\.io' | sort) <(printf '%s\n' 'tests/test-issue-788-host-purity-delta.sh' 'scripts/test/check-host-purity-delta.sh' 'tests/test-issue-985-doc-assertions.sh' | sort) >/dev/null"

# AC1-INTERNAL-DOCS-ABSENT: each removed path is absent from git ls-files.
# NOTE (ledger Q1 retarget): docs/improvement-backlog.md is EXCLUDED from
# this removed-paths loop. Ledger entry Q1 supersedes the original full
# deletion — the file is restored as an empty-start public artifact (the
# internal audit history is stripped, not the path itself; #954's live
# PREFLIGHT-scan append target and its docs/maintained-docs.md registry row
# both depend on the path surviving). See the dedicated
# AC1-BACKLOG-EMPTY-START assertion below in place of an absence check.
for removed in \
  "docs/host-service-decoupling-plan.md" \
  "docs/librechat-deploy-extraction-plan.md" \
  "docs/LibreChat_프로젝트안.docx" \
  "Jenkinsfile"
do
  assert_false "AC1-INTERNAL-DOCS-ABSENT: $removed is absent from git ls-files" \
    "git ls-files --error-unmatch '$removed' >/dev/null 2>&1"
done
assert_false "AC1-INTERNAL-DOCS-ABSENT: docs/adr/0001-*.md is absent from git ls-files" \
  "[ -n \"\$(git ls-files 'docs/adr/0001-*.md')\" ]"

# AC1-BACKLOG-EMPTY-START (ledger Q1): docs/improvement-backlog.md survives
# as a tracked path but carries no internal audit/finding blocks — the
# public tree starts with an empty Findings section (no '### `<id>`' entry).
assert_true "AC1-BACKLOG-EMPTY-START: docs/improvement-backlog.md is tracked with no internal finding blocks" \
  "git ls-files --error-unmatch 'docs/improvement-backlog.md' >/dev/null 2>&1 && ! grep -qE '^### \`(xissue-scan-|[a-zA-Z0-9_-]+-[0-9])' '$PROJECT_ROOT/docs/improvement-backlog.md' 2>/dev/null"

# AC1-DIGEST-EMPTIED: public tree starts with an empty cycle-digest.jsonl.
assert_true "AC1-DIGEST-EMPTIED: docs/cycle-digest.jsonl has 0 lines (path preserved, D4)" \
  "[ -f '$CYCLE_DIGEST' ] && [ \"\$(wc -l < '$CYCLE_DIGEST' | tr -d ' ')\" = '0' ]"

# AC1-NO-DANGLING-REF: once docs/adr/0001 is deleted, no surviving tracked
# file references its basename (known inbound refs per feature design
# Part 7/W4: docs/adr/README.md, docs/maintained-docs.md, setup/manifest.json,
# tests/fixtures/e2e-bundle-purity-baseline.txt).
assert_true "AC1-NO-DANGLING-REF: docs/adr/0001 is deleted and no tracked file still references its basename" \
  "[ -z \"\$(git ls-files 'docs/adr/0001-*.md')\" ] && [ -z \"\$(git grep -l '0001-host-orchestrator-and-librechat-submodule-boundary' -- ':!docs/adr/0001-*' ':!tests/test-issue-985-doc-assertions.sh' 2>/dev/null)\" ]"

# =============================================================================
echo ""
echo "=== AC2 — plugin key autoflow@autoflow consistency ==="

assert_true "AC2-KEY-CONSISTENT: no surviving 'autoflow@claude-autoflow' literal" \
  "[ -z \"\$(git grep -F 'autoflow@claude-autoflow' -- ':!tests/test-issue-985-doc-assertions.sh' 2>/dev/null)\" ]"

# =============================================================================
echo ""
echo "=== AC3 — LICENSE / SPDX / REUSE ==="

assert_true "AC3-SPDX-COVERAGE: REUSE.toml exists" \
  "[ -f '$REUSE_TOML' ]"
assert_true "AC3-SPDX-COVERAGE: LICENSES/Elastic-2.0.txt exists (Elastic-2.0 is SPDX-listed - no LicenseRef file)" \
  "[ -f '$LICENSES_DIR/Elastic-2.0.txt' ]"
assert_false "AC3-SPDX-COVERAGE: LICENSES/LicenseRef-PolyForm-Internal-Use-1.0.0.txt is absent" \
  "[ -f '$LICENSES_DIR/LicenseRef-PolyForm-Internal-Use-1.0.0.txt' ]"

# Enumerate the header-bearing set from the CURRENT (post-change-at-VERIFY)
# tree, not a hardcoded pre-change count (verification design ROUND-1
# correction / feature design §6b OC-3 close).
missing_header=""
# REUSE-IgnoreStart
while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ -f "$PROJECT_ROOT/$f" ] || continue
  if ! grep -q "SPDX-License-Identifier: Elastic-2.0" "$PROJECT_ROOT/$f" 2>/dev/null; then
    missing_header="$missing_header$f"$'\n'
  fi
done <<< "$(cd "$PROJECT_ROOT" && git ls-files -- '*.sh' '*.py' '*.bats' '*.yml' '*.js' '*.mjs')"
# REUSE-IgnoreEnd

header_bearing_count="$(cd "$PROJECT_ROOT" && git ls-files -- '*.sh' '*.py' '*.bats' '*.yml' '*.js' '*.mjs' | wc -l | tr -d ' ')"
echo "  header-bearing tracked files (post-change-tree enumeration): $header_bearing_count"
if [ -n "$missing_header" ]; then
  echo "  missing SPDX header ($(printf '%s' "$missing_header" | grep -c .) files):"
  printf '%s' "$missing_header" | sed 's/^/    /' | head -10
  [ "$(printf '%s' "$missing_header" | grep -c .)" -gt 10 ] && echo "    ... (truncated)"
fi
# REUSE-IgnoreStart
assert_true "AC3-SPDX-COVERAGE: every tracked .sh/.py/.bats/.yml/.js/.mjs file carries the SPDX-License-Identifier: Elastic-2.0 line" \
  "[ -z '$missing_header' ]"
# REUSE-IgnoreEnd

assert_true "AC3-SPDX-COVERAGE: no surviving 'LicenseRef-PolyForm-Internal-Use-1.0.0' token anywhere tracked" \
  "[ -z \"\$(git grep -F 'LicenseRef-PolyForm-Internal-Use-1.0.0' -- ':!tests/test-issue-985-doc-assertions.sh' ':!tests/manual/issue-985-manual-scenarios.md' 2>/dev/null)\" ]"

assert_true "AC3-WORKFLOW-COUNT: .github/workflows/ carries 6 workflows (5 existing + reuse.yml)" \
  "[ \"\$(ls -1 '$WORKFLOWS_DIR' 2>/dev/null | wc -l | tr -d ' ')\" = '6' ]"
assert_true "AC3-WORKFLOW-COUNT: reuse.yml is present alongside the 5 existing workflows" \
  "[ -f '$WORKFLOWS_DIR/reuse.yml' ] && [ -f '$WORKFLOWS_DIR/e2e-dummy-target.yml' ] && [ -f '$WORKFLOWS_DIR/host-purity-delta.yml' ] && [ -f '$WORKFLOWS_DIR/plugin-package.yml' ] && [ -f '$WORKFLOWS_DIR/schema-hook-contract.yml' ] && [ -f '$WORKFLOWS_DIR/workflow-regression.yml' ]"

# =============================================================================
echo ""
echo "=== Implicit AC — LICENSE / LICENSES/ ref file ==="

assert_true "AC-LICENSE: LICENSE carries the Elastic License 2.0 distinctive marker (not MIT, not PolyForm)" \
  "head -5 '$LICENSE_FILE' | grep -qi 'Elastic License'"
assert_false "AC-LICENSE: LICENSE no longer opens with 'MIT License'" \
  "head -1 '$LICENSE_FILE' | grep -q '^MIT License'"
assert_false "AC-LICENSE: LICENSE no longer carries the PolyForm Internal Use marker" \
  "head -5 '$LICENSE_FILE' | grep -qi 'PolyForm Internal Use'"
assert_true "AC-LICENSE: LICENSE carries the Copyright (c) 2026 Munsik-Park notice" \
  "grep -q 'Copyright (c) 2026 Munsik-Park' '$LICENSE_FILE'"
assert_true "AC-LICENSE: LICENSES/Elastic-2.0.txt exists with content" \
  "[ -s '$LICENSES_DIR/Elastic-2.0.txt' ]"
assert_false "AC-LICENSE: LICENSES/LicenseRef-PolyForm-Internal-Use-1.0.0.txt is absent" \
  "[ -f '$LICENSES_DIR/LicenseRef-PolyForm-Internal-Use-1.0.0.txt' ]"

# =============================================================================
echo ""
echo "=== AC4 — public README single plugin-install narrative ==="

assert_true "AC4-INSTALL-PATH: README contains '/plugin marketplace add Munsik-Park/autoflow'" \
  "grep -qF '/plugin marketplace add Munsik-Park/autoflow' '$README'"
assert_false "AC4-INSTALL-PATH: README no longer contains 'connev-llm'" \
  "grep -qi 'connev-llm' '$README'"
assert_true "AC4-LICENSE-SUMMARY: README carries an Elastic License 2.0 allow/deny summary section" \
  "grep -qi 'Elastic License' '$README'"
assert_true "AC4-LICENSE-SUMMARY: README states hosted/managed-service provision is prohibited" \
  "grep -qi 'hosted' '$README' && grep -qi 'managed service' '$README'"
assert_true "AC4-LICENSE-SUMMARY: README carries the one-line commercial-exception notice (commercial license + contact path)" \
  "grep -qi 'commercial license' '$README'"

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
