#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: INTEGRATE deploy/CI-path conditional verification — Issue #847
# =============================================================================
# Tier-1 scripted assertion suite per verification design
# (.autoflow/issue-847-verification-design.md). Docs-only change (no jest, no
# npm) — mirrors tests/test-issue-949-manifest-regen-doc.sh /
# tests/test-issue-846-doc-assertions.sh / tests/test-issue-848-doc-assertions.sh:
# assert_true/assert_false over grep + extract_section; set -uo pipefail;
# SIGPIPE-safe pipes per #964 (no `grep -[ABC] … | grep -q`).
#
# Scope (verification design §1/§3/§5):
#   AC1-a              — RED discriminator: INTEGRATE body carries the
#                         "### Deploy/CI-path conditional verification"
#                         sub-heading.
#   AC1-b              — RED discriminator: the subsection names all four
#                         trigger classes.
#   AC1-c              — RED discriminator: the subsection names all three
#                         bundle items (dry-run+recursive submodule init;
#                         CI static/lint validation; routing/landing smoke).
#   AC2-a              — RED discriminator (determinism): the trigger is
#                         stated as a command (`git diff --name-only` +
#                         `grep -E`), not prose.
#   AC2-COHERENCE-EXEC — RED discriminator (byte-identity, doc==constant
#                         half): INTEGRATE body contains the frozen
#                         TRIGGER_REGEX verbatim on the un-joined body.
#   AC2-EXEC-POS       — guard (constant-works half, inclusion oracle):
#                         TRIGGER_REGEX matches every witness fixture (one
#                         per regex OR-branch, verification design §5).
#                         Self-contained; PASSes pre-edit.
#   AC2-EXEC-NEG       — guard (over-breadth oracle): TRIGGER_REGEX does NOT
#                         match any near-miss control (verification design
#                         §5). Self-contained; PASSes pre-edit.
#   AC-COHERENCE       — guard: VALIDATE item 6 references the SAME
#                         canonical name as INTEGRATE (deploy/CI-path +
#                         the subsection heading text), not an independently
#                         worded second mechanism (#949 AC2-COHERENCE
#                         analogue).
#   AC-NOOP            — guard: INTEGRATE subsection AND VALIDATE item 6
#                         both carry the defined-no-op alternate-PASS clause
#                         (token "no deploy/CI-path surface").
#   AC-FAIL            — guard: the subsection states the FAIL disposition
#                         (INTEGRATE FAIL -> RED), no new regression cap.
#   AC-PRESERVE        — guard: the existing INTEGRATE single-repo no-op
#                         sentence + multi-repo 4-step block survive;
#                         VALIDATE items 1-5 + the existing verdict line
#                         survive (no wholesale deletion).
#   AC-CI-REGISTER     — RED discriminator: this suite is wired into
#                         .github/workflows/e2e-dummy-target.yml (both
#                         `paths:` blocks + a `run:` step), #949/#964/#846/
#                         #848 precedent.
#
# Not in this file (verification design §4, Tier 3 — delegated to
# tests/manual/issue-847-manual-scenarios.md):
#   BUNDLE-LIVE-(a)/(b)/(c) — the live effectiveness of the bundle commands
#   against a real target service repo; this single-repo framework repo has
#   no deploy script / service CI / host route to exercise.
#
# RED expectation (pre-edit, this commit): AC1-a/b/c, AC2-a,
# AC2-COHERENCE-EXEC, AC-COHERENCE, AC-NOOP, AC-FAIL, AC-CI-REGISTER FAIL
# (the subsection/item/registration/verbatim-regex do not exist in the doc
# yet).
#
# JUSTIFIED PRE-EDIT PASSES (guards, NOT RED discriminators; verification
# design §3 "RED expectation" ruling):
#   AC2-EXEC-POS/NEG — self-contained regex-vs-fixture oracles; pass once the
#     TRIGGER_REGEX constant is embedded in this test, independent of the doc
#     edit.
#   AC-PRESERVE      — PASSes pre+post: nothing has been removed yet.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GUIDE_MD="$PROJECT_ROOT/docs/autoflow-guide.md"
CI_WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"

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
# (verification design: "Section scope uses the shared extractor"). Body runs
# from the heading line (exclusive) to the next "## " heading or a bare
# "---" separator, whichever comes first (identical to
# tests/test-issue-949-manifest-regen-doc.sh extract_section).
# ---------------------------------------------------------------------------

extract_section() {
  local heading_pattern="$1" file="$2"
  awk -v p="$heading_pattern" '
    $0 ~ p { f=1; next }
    f && /^## / { f=0 }
    f && /^---$/ { f=0 }
    f { print }
  ' "$file"
}

INTEGRATE_BODY="$(extract_section '^## INTEGRATE' "$GUIDE_MD")"
VALIDATE_BODY="$(extract_section '^## VALIDATE' "$GUIDE_MD")"

INTEGRATE_JOINED="$(printf '%s' "$INTEGRATE_BODY" | tr '\n' ' ')"
VALIDATE_JOINED="$(printf '%s' "$VALIDATE_BODY" | tr '\n' ' ')"

# Sub-scoped extractor: the new "### Deploy/CI-path conditional
# verification" sub-heading, bounded to its own body (stops at the next
# "### "/"## " heading or a bare "---"). Scoping AC1-b/c, AC-NOOP-a and
# AC-FAIL to this sub-body (rather than the whole INTEGRATE_JOINED) avoids a
# false PASS against the pre-existing, unrelated generic
# "**Failure**: INTEGRATE FAIL -> RED" sentence that already lives elsewhere
# in the INTEGRATE section.
extract_subsection() {
  local heading_pattern="$1" file="$2"
  awk -v p="$heading_pattern" '
    $0 ~ p { f=1; next }
    f && /^### / { f=0 }
    f && /^## / { f=0 }
    f && /^---$/ { f=0 }
    f { print }
  ' "$file"
}

SUBSECTION_BODY="$(extract_subsection '^### Deploy/CI-path conditional verification' "$GUIDE_MD")"
SUBSECTION_JOINED="$(printf '%s' "$SUBSECTION_BODY" | tr '\n' ' ')"

export INTEGRATE_JOINED VALIDATE_JOINED SUBSECTION_JOINED

# =============================================================================
echo "=== §1 Canonical trigger regex (frozen — byte-identity anchor) ==="
# The single deterministic string, empirically validated against witnesses
# and near-miss controls (verification design §1).

TRIGGER_REGEX='(^|/)\.gitmodules$|(^|/)\.github/workflows/|(^|/)Jenkinsfile$|(^|/)deploy-[^/]*\.sh$|(^|/)\.env(\.[^/]*)?$'
export TRIGGER_REGEX

# =============================================================================
echo ""
echo "=== AC1 (RED discriminator) — INTEGRATE deploy/CI-path subsection ==="

assert_true "AC1-a: INTEGRATE body carries the '### Deploy/CI-path conditional verification' sub-heading" \
  "printf '%s' \"\$INTEGRATE_JOINED\" | grep -qF '### Deploy/CI-path conditional verification'"

assert_true "AC1-b: subsection names all four trigger classes (.gitmodules, .github/workflows, Jenkinsfile, deploy-, .env)" \
  "printf '%s' \"\$SUBSECTION_JOINED\" | grep -qF '.gitmodules' \
    && printf '%s' \"\$SUBSECTION_JOINED\" | grep -qF '.github/workflows' \
    && printf '%s' \"\$SUBSECTION_JOINED\" | grep -qF 'Jenkinsfile' \
    && printf '%s' \"\$SUBSECTION_JOINED\" | grep -qF 'deploy-' \
    && printf '%s' \"\$SUBSECTION_JOINED\" | grep -qF '.env'"

assert_true "AC1-c: subsection names all three bundle items (dry-run+--init --recursive; CI static/lint validation; routing/landing smoke)" \
  "printf '%s' \"\$SUBSECTION_JOINED\" | grep -qF 'dry-run' \
    && printf '%s' \"\$SUBSECTION_JOINED\" | grep -qF -- '--init --recursive' \
    && printf '%s' \"\$SUBSECTION_JOINED\" | grep -qE 'actionlint|declarative-linter|lint' \
    && printf '%s' \"\$SUBSECTION_JOINED\" | grep -qE 'routing|landing' \
    && printf '%s' \"\$SUBSECTION_JOINED\" | grep -qF 'smoke'"

# =============================================================================
echo ""
echo "=== AC2-a (RED discriminator, determinism) — trigger stated as a command ==="

assert_true "AC2-a: INTEGRATE body contains 'git diff --name-only' AND 'grep -E' (concrete command, not prose)" \
  "printf '%s' \"\$INTEGRATE_JOINED\" | grep -qF 'git diff --name-only' \
    && printf '%s' \"\$INTEGRATE_JOINED\" | grep -qF 'grep -E'"

# =============================================================================
echo ""
echo "=== AC2-COHERENCE-EXEC (byte-identity, doc==constant half) ==="
# Run over the UN-JOINED INTEGRATE body (line breaks preserved) since the
# frozen pattern is a single physical line (verification design §2 step 2).

assert_true "AC2-COHERENCE-EXEC: INTEGRATE body contains the frozen TRIGGER_REGEX verbatim on one physical line" \
  "printf '%s' \"\$INTEGRATE_BODY\" | grep -qF -- \"\$TRIGGER_REGEX\""

# =============================================================================
echo ""
echo "=== AC2-EXEC-POS (guard, inclusion oracle — constant-works half) ==="
# One positive witness per regex OR-branch (verification design §5 fixture
# canon, frozen — supersedes feature design §5 line 129's illustrative array).

POS_FIXTURES=(
  "services/librechat-deploy/.gitmodules"
  ".github/workflows/ci.yml"
  "Jenkinsfile"
  "deploy-librechat.sh"
  "services/.env"
)
for f in "${POS_FIXTURES[@]}"; do
  assert_true "AC2-EXEC-POS: TRIGGER_REGEX matches '$f'" \
    "printf '%s' '$f' | grep -qE -- \"\$TRIGGER_REGEX\""
done

# =============================================================================
echo ""
echo "=== AC2-EXEC-NEG (guard, over-breadth oracle) ==="
# Near-miss controls (verification design §5 fixture canon).

NEG_FIXTURES=(
  "docs/autoflow-guide.md"
  "myapp.env"
  "docs/deploy-notes.md"
  "predeploy-x.sh"
  "Jenkinsfile.groovy"
  ".github/ISSUE_TEMPLATE/bug.md"
)
for f in "${NEG_FIXTURES[@]}"; do
  assert_false "AC2-EXEC-NEG: TRIGGER_REGEX does NOT match '$f'" \
    "printf '%s' '$f' | grep -qE -- \"\$TRIGGER_REGEX\""
done

# =============================================================================
echo ""
echo "=== AC-COHERENCE (guard) — INTEGRATE and VALIDATE reference the SAME name ==="

assert_true "AC-COHERENCE-a: INTEGRATE body references 'Deploy/CI-path' (canonical name)" \
  "printf '%s' \"\$INTEGRATE_JOINED\" | grep -qF 'Deploy/CI-path'"
assert_true "AC-COHERENCE-b: VALIDATE body references the canonical subsection name '### Deploy/CI-path conditional verification'" \
  "printf '%s' \"\$VALIDATE_JOINED\" | grep -qF 'Deploy/CI-path conditional verification'"

# =============================================================================
echo ""
echo "=== AC-NOOP (guard) — defined-no-op alternate-PASS clause, both anchors ==="

assert_true "AC-NOOP-a: INTEGRATE subsection carries the defined-no-op clause ('no deploy/CI-path surface')" \
  "printf '%s' \"\$SUBSECTION_JOINED\" | grep -qF 'no deploy/CI-path surface'"
assert_true "AC-NOOP-b: VALIDATE item 6 carries the same defined-no-op clause ('no deploy/CI-path surface')" \
  "printf '%s' \"\$VALIDATE_JOINED\" | grep -qF 'no deploy/CI-path surface'"

# =============================================================================
echo ""
echo "=== AC-FAIL (guard) — FAIL disposition (INTEGRATE FAIL -> RED), no new cap ==="

assert_true "AC-FAIL: subsection states the FAIL disposition (INTEGRATE FAIL -> RED)" \
  "printf '%s' \"\$SUBSECTION_JOINED\" | grep -qE 'INTEGRATE FAIL.*RED|FAIL.*->.*RED|FAIL.*→.*RED'"

# =============================================================================
echo ""
echo "=== AC-PRESERVE (guard) — existing INTEGRATE/VALIDATE content survives ==="

assert_true "AC-PRESERVE-a: existing INTEGRATE single-repo no-op sentence retained ('no-op (single-repo')" \
  "printf '%s' \"\$INTEGRATE_JOINED\" | grep -qF 'no-op (single-repo'"
assert_true "AC-PRESERVE-b: VALIDATE item 1 (automated tests all PASS) retained" \
  "printf '%s' \"\$VALIDATE_JOINED\" | grep -qF 'Automated tests: all PASS confirmed'"
assert_true "AC-PRESERVE-c: VALIDATE item 5 (manifest coherence) retained" \
  "printf '%s' \"\$VALIDATE_JOINED\" | grep -qiF 'manifest coherence' && printf '%s' \"\$VALIDATE_JOINED\" | grep -qF '5.'"

# =============================================================================
echo ""
echo "=== AC-CI-REGISTER (RED discriminator) — suite wired into e2e-dummy-target.yml ==="

if [[ -f "$CI_WORKFLOW" ]]; then
  assert_true "AC-CI-a: e2e-dummy-target.yml references test-issue-847-doc-assertions.sh (>= 3 occurrences: 2 paths blocks + 1 run step)" \
    "[ \"\$(grep -c 'test-issue-847-doc-assertions' '$CI_WORKFLOW')\" -ge 3 ]"
  assert_true "AC-CI-b: reference appears in a 'paths:' trigger block" \
    "grep -B30 'test-issue-847-doc-assertions' '$CI_WORKFLOW' | grep '^ *paths:' >/dev/null"
  assert_true "AC-CI-c: reference appears in a 'run:' step" \
    "ctx=\$(grep -A2 'test-issue-847-doc-assertions' '$CI_WORKFLOW'); printf '%s\n' \"\$ctx\" | grep -q 'run: bash tests/test-issue-847-doc-assertions.sh'"
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
