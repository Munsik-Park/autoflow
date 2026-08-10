#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: gate-score write contract at the producer site — Issue #55
# =============================================================================
# Tier-1 scripted assertion suite per verification design
# (.autoflow/issue-55-verification-design.md). Doc + hook-diagnostic + fixture
# change (no jest, no npm) — mirrors tests/test-gate-hardening.sh /
# tests/test-issue-245-schema-validation.sh: assert_true/run_hook(_stderr)
# over grep/awk/jq + real subprocess hook invocation.
#
# Scope (verification design Part 1):
#   producer-shape              — CLAUDE.md carries a marker-anchored,
#                                  jq-parseable, hook-admissible JSON fence.
#   single-source                — tests/fixtures/gate-schema.json declares
#                                  score_shapes; agreement is by execution.
#   diagnostic-hint-malformed    — the reachable (live-incident) fail-closed
#                                  diagnostic names the accepted shapes.
#   diagnostic-hint-not-evaluable — GATE:PLAN carried finding (ledger E15,
#                                  binding): after the #245 closed-world
#                                  validator, every admitted `scores` entry
#                                  already satisfies `is_score`, so
#                                  check_scores' `tonumber` cannot error and
#                                  block_with_scores' "not evaluable" branch
#                                  is unreachable via any real hook input
#                                  (tests/test-issue-245-schema-validation.sh:428
#                                  documents the same closed-world admission).
#                                  Resolved per the verification design's
#                                  Discriminators section (Part 1) by asserting
#                                  the hint text statically, on the diagnostic's
#                                  own source line, instead of driving an
#                                  unconstructible input through it.
#   registry-entries-added       — 4 origin_issue:55 doc-invariant entries.
#   ci-self-registration         — new suite + manual scenario wired into
#                                  e2e-dummy-target.yml (both paths: blocks +
#                                  a run: step), tail-appended per the E6/E7
#                                  ledger decisions (no reorder of existing
#                                  entries — AC6-ci's fixed grep -A40 window
#                                  has zero headroom).
#   manual-scenario-present       — tests/manual/issue-55-manual-scenarios.md
#                                  exists and carries instruction-is-followed.
#   single-source's shape-set equality & execution arms —
#                                  GUARDS (verification-design Discriminators:
#                                  not RED-first), vacuously satisfied while
#                                  their precondition (the score_shapes key)
#                                  does not exist yet.
#   committed-surface-completeness — DELIVER-time guard (not RED-first),
#                                  checked against the Part 5 9-file allow-list.
#
# Deliberately NOT reimplemented here (verification design Part 1 — the cycle
# suite adds no second implementation):
#   no-behavior-change — regression floor: tests/test-gate-hardening.sh,
#     tests/test-issue-245-schema-validation.sh,
#     tests/test-issue-223-schema-hook-contract.sh,
#     tests/test-issue-961-cap6-gate.sh,
#     tests/test-issue-18-fixture-glob-isolation.sh, tests/run-doc-invariants.sh,
#     tests/test-issue-799-inert-cleanup.sh, tests/test-issue-27-composition-oracle.sh,
#     tests/test-issue-35-phase-marker.sh, tests/test-issue-62-sequential-rounds.sh
#     — run separately by the Test AI / orchestrator, not embedded here.
#   manifest-consistency — oracle is tests/plugin/verify-install-into-target.sh AC2e.
#   mirror-parity — oracle is tests/test-gate-hardening.sh AC-2g (diff -q).
#
# RED expectation (pre-implementation, this commit): producer-shape (a/a2/b/c),
# single-source (has-key arm), diagnostic-hint-malformed,
# diagnostic-hint-not-evaluable, registry-entries-added, ci-self-registration
# (all sub-arms) and manual-scenario-present all FAIL. Guard arms
# (single-source's equality/execution sub-arms, the ci-self-
# registration companion window, committed-surface-completeness) PASS.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

HOOK="$PROJECT_ROOT/.claude/hooks/check-autoflow-gate.sh"
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
GATE_SCHEMA="$PROJECT_ROOT/tests/fixtures/gate-schema.json"
DOC_INVARIANTS="$PROJECT_ROOT/tests/fixtures/doc-invariants.json"
REGISTRY_RUNNER="$PROJECT_ROOT/tests/run-doc-invariants.sh"
CI_WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"
MANUAL_SCENARIOS="$PROJECT_ROOT/tests/manual/issue-55-manual-scenarios.md"
BASEREF_LIB="$PROJECT_ROOT/tests/lib/base-ref.sh"

SUITE_PATH="tests/test-issue-55-score-format-contract.sh"
MANUAL_PATH="tests/manual/issue-55-manual-scenarios.md"
MARKER='<!-- SCORE-SHAPE-EXAMPLE -->'
# Single spelling asserted at both fail-closed diagnostic sites (feature
# design > Change surface > diagnostic hint > proposed line).
HINT_SUBSTR='Accepted score shapes'

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

# run_hook <expected_exit> <desc> <project_dir> <json>
run_hook() {
  local expected="$1" desc="$2" pdir="$3" json="$4" actual
  actual=$(printf '%s' "$json" | CLAUDE_PROJECT_DIR="$pdir" bash "$HOOK" >/dev/null 2>&1; echo $?)
  TESTS=$((TESTS + 1))
  if [[ "$actual" == "$expected" ]]; then
    echo "  PASS: $desc (exit $actual)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected exit $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

# run_hook_stderr <expected_exit> <reason_substr> <desc> <project_dir> <json>
run_hook_stderr() {
  local expected="$1" reason_substr="$2" desc="$3" pdir="$4" json="$5"
  local actual stderr_out
  stderr_out=$(mktemp)
  actual=$(printf '%s' "$json" | CLAUDE_PROJECT_DIR="$pdir" bash "$HOOK" >/dev/null 2>"$stderr_out"; echo $?)
  local ok=1
  [[ "$actual" != "$expected" ]] && ok=0
  if [[ $ok -eq 1 ]] && ! grep -qF "$reason_substr" "$stderr_out"; then
    ok=0
  fi
  rm -f "$stderr_out"
  TESTS=$((TESTS + 1))
  if [[ $ok -eq 1 ]]; then
    echo "  PASS: $desc (exit $actual, reason contains '$reason_substr')"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected exit $expected w/ reason '$reason_substr', got exit $actual)"
    FAIL=$((FAIL + 1))
  fi
}

bash_json() { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(printf '%s' "$1" | jq -Rs .)"; }
agent_json() { printf '{"tool_name":"Agent","tool_input":{"subagent_type":%s,"prompt":%s,"model":%s}}' "$(printf '%s' "$1" | jq -Rs .)" "$(printf '%s' "$2" | jq -Rs .)" "$(printf '%s' "${3:-sonnet}" | jq -Rs .)"; }

WORKROOT="$(mktemp -d)"
trap 'rm -rf "$WORKROOT"' EXIT

# stage_fixture <json_content> -> prints the project_dir path
stage_fixture() {
  local content="$1" d
  d="$(mktemp -d -p "$WORKROOT")"
  mkdir -p "$d/.autoflow"
  printf '%s' "$content" > "$d/.autoflow/issue-55.json"
  echo "$d"
}

# =============================================================================
# Marker + fence extraction (producer-shape's fixed extractor, Part 1)
# =============================================================================
marker_count() { grep -cxF "$MARKER" "$CLAUDE_MD" 2>/dev/null || true; }

marker_line() { grep -nxF "$MARKER" "$CLAUDE_MD" 2>/dev/null | head -1 | cut -d: -f1; }

fence_opens_after_marker() {
  local mline nline
  mline="$(marker_line)"
  [ -n "$mline" ] || return 1
  nline=$((mline + 1))
  [ "$(sed -n "${nline}p" "$CLAUDE_MD")" = '```json' ]
}

extract_fence_body() {
  local mline start
  mline="$(marker_line)"
  [ -n "$mline" ] || return 1
  start=$((mline + 2))
  awk -v start="$start" 'NR>=start { if ($0=="```") exit; print }' "$CLAUDE_MD"
}

MARKER_COUNT="$(marker_count)"
[ -z "$MARKER_COUNT" ] && MARKER_COUNT=0
FENCE_OK=no
if [ "$MARKER_COUNT" -eq 1 ] && fence_opens_after_marker; then FENCE_OK=yes; fi

FENCE_BODY=""
FENCE_PARSE_OK=no
if [ "$FENCE_OK" = yes ]; then
  FENCE_BODY="$(extract_fence_body)"
  if printf '%s' "$FENCE_BODY" | jq -e 'type=="object"' >/dev/null 2>&1; then
    FENCE_PARSE_OK=yes
  fi
fi

echo "=== producer-shape (AC: Producer example) ==="
assert_true "producer-shape-a: exactly one bare $MARKER marker at column 0 in CLAUDE.md (got: $MARKER_COUNT)" \
  "[ '$MARKER_COUNT' -eq 1 ]"
assert_true "producer-shape-a2: the line immediately after the marker opens a \`\`\`json fence at column 0 (got: $FENCE_OK)" \
  "[ '$FENCE_OK' = yes ]"
assert_true "producer-shape-b: the extracted fence body parses under real jq as one complete object (got: $FENCE_PARSE_OK)" \
  "[ '$FENCE_PARSE_OK' = yes ]"

if [ "$FENCE_PARSE_OK" = yes ]; then
  DRIVE_DIR="$(mktemp -d -p "$WORKROOT")"
  mkdir -p "$DRIVE_DIR/.autoflow"
  jq -n --argjson scores "$FENCE_BODY" '{active:true, issue:"#55", phases:{gate_plan:{scores:$scores}}}' \
    > "$DRIVE_DIR/.autoflow/issue-55.json"
  run_hook 0 "producer-shape-c: the extracted example installed verbatim as phases.gate_plan.scores is admitted by the real hook (implementer spawn)" \
    "$DRIVE_DIR" "$(agent_json 'autoflow-implementer' 'make the failing tests pass')"
else
  assert_true "producer-shape-c: extracted example admitted by the real hook (unmeasurable — extraction failed above)" "false"
fi

# =============================================================================
# single-source (AC: Single shape source)
# =============================================================================
echo ""
echo "=== single-source (AC: Single shape source) ==="

HAS_SHAPES=no
jq -e 'has("score_shapes")' "$GATE_SCHEMA" >/dev/null 2>&1 && HAS_SHAPES=yes
assert_true "single-source-a: tests/fixtures/gate-schema.json declares a score_shapes key (got: $HAS_SHAPES)" \
  "[ '$HAS_SHAPES' = yes ]"

if [ "$HAS_SHAPES" = yes ]; then
  # Execution admission: each declared shape, injected as a phases.gate_plan.scores
  # entry, is admitted by the real hook; a prose-string counter-shape is rejected
  # by the same path.
  IDX=0
  while : ; do
    SHAPE="$(jq -c ".score_shapes[$IDX] // empty" "$GATE_SCHEMA" 2>/dev/null)"
    [ -z "$SHAPE" ] && break
    SDIR="$(mktemp -d -p "$WORKROOT")"
    mkdir -p "$SDIR/.autoflow"
    jq -n --argjson v "$SHAPE" '{active:true, issue:"#55", phases:{gate_plan:{scores:{a:$v}}}}' \
      > "$SDIR/.autoflow/issue-55.json"
    run_hook 0 "single-source-b$IDX: declared shape #$IDX ($SHAPE) admitted by the real hook" \
      "$SDIR" "$(agent_json 'autoflow-implementer' 'make the failing tests pass')"
    IDX=$((IDX + 1))
  done

  PROSE_DIR="$(mktemp -d -p "$WORKROOT")"
  mkdir -p "$PROSE_DIR/.autoflow"
  printf '%s' '{"active":true,"issue":"#55","phases":{"gate_plan":{"scores":{"a":"9 - reason"}}}}' \
    > "$PROSE_DIR/.autoflow/issue-55.json"
  run_hook 2 "single-source-c: a prose-string counter-shape is rejected by the same path" \
    "$PROSE_DIR" "$(agent_json 'autoflow-implementer' 'make the failing tests pass')"

  # Shape-set equality predicate (feature design > Change surface > shape
  # declaration > Comparison rule), guarded on the fence also existing.
  if [ "$FENCE_PARSE_OK" = yes ]; then
    FSET="$(printf '%s' "$FENCE_BODY" | jq -c 'to_entries | map(.value | if type=="object" then "object" else type end) | unique | sort')"
    DSET="$(jq -c '.score_shapes | map(if type=="object" then "object" else type end) | unique | sort' "$GATE_SCHEMA")"
    assert_true "single-source-d: shape-set equality — fence value-shapes ($FSET) == declared shapes ($DSET)" \
      "[ '$FSET' = '$DSET' ]"
  else
    assert_true "single-source-d: shape-set equality (guard, vacuously satisfied — CLAUDE.md fence not yet extractable)" "true"
  fi
else
  assert_true "single-source-b/c/d: execution admission + shape-set equality (guard, vacuously satisfied — score_shapes key not yet declared)" "true"
fi

# =============================================================================
# diagnostic-hint-malformed (oracle: incident-replay)
# =============================================================================
echo ""
echo "=== diagnostic-hint-malformed (oracle: incident-replay) ==="
# Reproduces the live incident exactly (feature design > Problem this cycle
# closes): a prose-string score inside a gated phase is rejected by the
# closed-world admission validator BEFORE any specific gate logic runs, so
# ANY score-gated command (here: git push) reaches the MALFORMED diagnostic.
run_hook_stderr 2 "$HINT_SUBSTR" \
  "diagnostic-hint-malformed: real hook, gate_plan score is a prose string, git push -> exit 2, stderr names the accepted shapes" \
  "$(stage_fixture '{"active":true,"issue":"#55","phases":{"gate_plan":{"scores":{"a":"9 - reason"}}}}')" \
  "$(bash_json 'git push origin dev/55')"

# =============================================================================
# diagnostic-hint-not-evaluable (static form — GATE:PLAN carried finding,
# ledger E15) — the dynamic tonumber-error path inside check_scores /
# block_with_scores is UNREACHABLE via any real hook input once the #245
# closed-world admission validator has run: every score that reaches
# check_scores already satisfied is_score (number, or {score:number} in
# [0,10]) at admission, so tonumber cannot subsequently error
# (tests/test-issue-245-schema-validation.sh:428 documents the same
# closed-world property for the schema-deviation class). Resolved per the
# verification design's Discriminators section by asserting the hint
# statically on the diagnostic's own source text, at the exact site named
# by the feature design (.claude/hooks/check-autoflow-gate.sh:516-521).
# =============================================================================
echo ""
echo "=== diagnostic-hint-not-evaluable (static form, ledger E15 resolution) ==="

NE_CTX="$(grep -A3 -F 'state scores are not evaluable' "$HOOK" 2>/dev/null || true)"
NE_HAS_HINT=no
printf '%s\n' "$NE_CTX" | grep -qF "$HINT_SUBSTR" && NE_HAS_HINT=yes
assert_true "diagnostic-hint-not-evaluable: the 'not evaluable' fail-closed diagnostic's own source names the accepted shapes (static — the dynamic path is unreachable after #245's closed-world validator) (got: $NE_HAS_HINT)" \
  "[ '$NE_HAS_HINT' = yes ]"

# Single-spelling check: the same hint substring occurs exactly twice in the
# hook (the malformed site + the not-evaluable site), never a third divergent
# copy (feature design: "Proposed line, identical at both sites").
HINT_OCCURRENCES="$(grep -cF "$HINT_SUBSTR" "$HOOK" 2>/dev/null || true)"
[ -z "$HINT_OCCURRENCES" ] && HINT_OCCURRENCES=0
assert_true "diagnostic-hint-parity: the accepted-shape hint occurs exactly twice in the hook (one per fail-closed site) (got: $HINT_OCCURRENCES)" \
  "[ '$HINT_OCCURRENCES' -eq 2 ]"

# =============================================================================
# registry-entries-added
# =============================================================================
echo ""
echo "=== registry-entries-added ==="

EXPECTED_IDS="55-score-shape-marker 55-score-shape-fence 55-score-shape-string-rejected 55-score-format-source-link"
for id in $EXPECTED_IDS; do
  ENTRY_OK="$(jq -c --arg id "$id" '[.invariants[] | select(.id==$id) | select(.file=="CLAUDE.md") | select(.predicate=="present") | select(.scope=="permanent") | select(.section=="AutoFlow State Tracking (Hook integration)")] | length' "$DOC_INVARIANTS" 2>/dev/null)"
  [ -z "$ENTRY_OK" ] && ENTRY_OK=0
  assert_true "registry-entries-added: entry '$id' present, file=CLAUDE.md, predicate=present, scope=permanent, anchored on the AutoFlow State Tracking section (got count: $ENTRY_OK)" \
    "[ '$ENTRY_OK' -eq 1 ]"
done

COUNT55="$(jq '[.invariants[] | select(.origin_issue==55)] | length' "$DOC_INVARIANTS" 2>/dev/null)"
[ -z "$COUNT55" ] && COUNT55=0
assert_true "registry-entries-added: exactly 4 origin_issue:55 entries exist (got: $COUNT55)" \
  "[ '$COUNT55' -eq 4 ]"

if [ "$COUNT55" -eq 4 ]; then
  RUNNER_OUT="$(bash "$REGISTRY_RUNNER" 2>&1)"
  RUNNER_EXIT=$?
  RUNNER_55_FAILS="$(printf '%s\n' "$RUNNER_OUT" | grep -c '^  FAIL: 55-' || true)"
  RUNNER_978_PASSES="$(printf '%s\n' "$RUNNER_OUT" | grep -c '^  PASS: 978-' || true)"
  assert_true "registry-entries-added: tests/run-doc-invariants.sh exits 0 (got: $RUNNER_EXIT)" "[ '$RUNNER_EXIT' -eq 0 ]"
  assert_true "registry-entries-added: no 55-* entry FAILs in the runner (got: $RUNNER_55_FAILS)" "[ '$RUNNER_55_FAILS' -eq 0 ]"
  assert_true "registry-entries-added: the pre-existing 978-* absent-guard entries on the same section still PASS (got: $RUNNER_978_PASSES)" "[ '$RUNNER_978_PASSES' -gt 0 ]"
else
  assert_true "registry-entries-added: run-doc-invariants.sh regression (unmeasurable — entries not yet added above)" "false"
  assert_true "registry-entries-added: no 55-* FAIL (unmeasurable — entries not yet added above)" "false"
  assert_true "registry-entries-added: pre-existing 978-* still PASS (unmeasurable — entries not yet added above)" "false"
fi

# =============================================================================
# ci-self-registration
# =============================================================================
echo ""
echo "=== ci-self-registration ==="

if [ -f "$CI_WORKFLOW" ]; then
  PR_SECTION="$(awk '/^  push:/{exit} {print}' "$CI_WORKFLOW")"
  PUSH_SECTION="$(awk 'f && /^[a-zA-Z]/{exit} f{print} /^  push:/{f=1}' "$CI_WORKFLOW")"

  PR_HAS_SUITE=no;   printf '%s\n' "$PR_SECTION"   | grep -qF "'$SUITE_PATH'"  && PR_HAS_SUITE=yes
  PUSH_HAS_SUITE=no; printf '%s\n' "$PUSH_SECTION" | grep -qF "'$SUITE_PATH'"  && PUSH_HAS_SUITE=yes
  PR_HAS_MANUAL=no;  printf '%s\n' "$PR_SECTION"   | grep -qF "'$MANUAL_PATH'" && PR_HAS_MANUAL=yes
  PUSH_HAS_MANUAL=no;printf '%s\n' "$PUSH_SECTION" | grep -qF "'$MANUAL_PATH'" && PUSH_HAS_MANUAL=yes

  assert_true "ci-self-registration-a1: $SUITE_PATH appears in the pull_request paths: block (got: $PR_HAS_SUITE)" "[ '$PR_HAS_SUITE' = yes ]"
  assert_true "ci-self-registration-a2: $SUITE_PATH appears in the push paths: block (got: $PUSH_HAS_SUITE)" "[ '$PUSH_HAS_SUITE' = yes ]"
  assert_true "ci-self-registration-a3: $MANUAL_PATH appears in the pull_request paths: block (got: $PR_HAS_MANUAL)" "[ '$PR_HAS_MANUAL' = yes ]"
  assert_true "ci-self-registration-a4: $MANUAL_PATH appears in the push paths: block (got: $PUSH_HAS_MANUAL)" "[ '$PUSH_HAS_MANUAL' = yes ]"

  RUN_STEP_CTX="$(grep -A2 -F "$SUITE_PATH" "$CI_WORKFLOW" 2>/dev/null || true)"
  RUN_STEP_OK=no; printf '%s\n' "$RUN_STEP_CTX" | grep -qF "run: bash $SUITE_PATH" && RUN_STEP_OK=yes
  assert_true "ci-self-registration-b: a 'run: bash $SUITE_PATH' step exists (got: $RUN_STEP_OK)" "[ '$RUN_STEP_OK' = yes ]"

  # Placement arm (ledger E6/E7 — asserted, not advised): both new entries
  # appear strictly below the last pre-existing entry of EACH block
  # ('tests/manual/issue-51-manual-scenarios.md').
  ANCHOR="'tests/manual/issue-51-manual-scenarios.md'"
  PR_ANCHOR_LN="$(printf '%s\n' "$PR_SECTION" | grep -nF "$ANCHOR" | tail -1 | cut -d: -f1)"
  PR_SUITE_LN="$(printf '%s\n' "$PR_SECTION" | grep -nF "'$SUITE_PATH'" | head -1 | cut -d: -f1)"
  PUSH_ANCHOR_LN="$(printf '%s\n' "$PUSH_SECTION" | grep -nF "$ANCHOR" | tail -1 | cut -d: -f1)"
  PUSH_SUITE_LN="$(printf '%s\n' "$PUSH_SECTION" | grep -nF "'$SUITE_PATH'" | head -1 | cut -d: -f1)"

  assert_true "ci-self-registration-placement-pr: new entry sits strictly below the block's last pre-existing entry (anchor@${PR_ANCHOR_LN:-absent}, suite@${PR_SUITE_LN:-absent})" \
    "[ -n '${PR_ANCHOR_LN:-}' ] && [ -n '${PR_SUITE_LN:-}' ] && [ '${PR_SUITE_LN:-0}' -gt '${PR_ANCHOR_LN:-0}' ]"
  assert_true "ci-self-registration-placement-push: new entry sits strictly below the block's last pre-existing entry (anchor@${PUSH_ANCHOR_LN:-absent}, suite@${PUSH_SUITE_LN:-absent})" \
    "[ -n '${PUSH_ANCHOR_LN:-}' ] && [ -n '${PUSH_SUITE_LN:-}' ] && [ '${PUSH_SUITE_LN:-0}' -gt '${PUSH_ANCHOR_LN:-0}' ]"

  # Companion window guard — a direct copy of test-issue-799-inert-cleanup.sh
  # AC6-ci's own expression (ledger E6: "so a placement mistake is attributed
  # to this cycle's own suite"). Green at HEAD; the guard this cycle must not
  # red.
  PH="$(grep -A40 '^ *paths:' "$CI_WORKFLOW")"
  assert_true "ci-self-registration-window-guard: e2e-dummy-target.yml's fixed grep -A40 '^ *paths:' window still contains 'docs/git-workflow.md' (AC6-ci's own literal — this cycle must tail-append, not push it out)" \
    "printf '%s\n' \"\$PH\" | grep -qF \"'docs/git-workflow.md'\""
else
  assert_true "ci-self-registration: $CI_WORKFLOW exists" "false"
  echo "  BLOCK: remaining ci-self-registration arms unmeasurable (workflow file missing) — counted FAIL, never skipped"
  TESTS=$((TESTS + 7)); FAIL=$((FAIL + 7))
fi

# =============================================================================
# manual-scenario-present
# =============================================================================
echo ""
echo "=== manual-scenario-present ==="

assert_true "manual-scenario-present-a: $MANUAL_PATH exists in the tracked tree" \
  "[ -f '$MANUAL_SCENARIOS' ]"

if [ -f "$MANUAL_SCENARIOS" ]; then
  assert_true "manual-scenario-present-b: the file names the instruction-is-followed scenario" \
    "grep -qi 'instruction-is-followed' '$MANUAL_SCENARIOS'"
else
  assert_true "manual-scenario-present-b: instruction-is-followed scenario named (unmeasurable — file missing above)" "false"
fi

# =============================================================================
# committed-surface-completeness (DELIVER-time guard, verification design
# Part 5 9-file allow-list) — not a RED-first item.
# =============================================================================
echo ""
echo "=== committed-surface-completeness (guard) ==="

if [ -f "$BASEREF_LIB" ]; then
  # shellcheck source=/dev/null
  source "$BASEREF_LIB"
  ALLOWLIST_55=(
    "CLAUDE.md"
    ".claude/hooks/check-autoflow-gate.sh"
    "plugin/autoflow/hooks/check-autoflow-gate.sh"
    "tests/fixtures/gate-schema.json"
    "tests/fixtures/doc-invariants.json"
    "$SUITE_PATH"
    "$MANUAL_PATH"
    ".github/workflows/e2e-dummy-target.yml"
    "setup/manifest.json"
    # Ledger E16 — the mechanical scope-guard admissions this repo's
    # branch-diff guards require of every cycle (precedent: 5b01eaf for #51,
    # 26ce222 for #67). Each of the six suites below carries an
    # `allow_list=( ... )` array governing the branch diff, and each is
    # amended in this cycle's commit to admit the members above; that
    # amendment is itself part of the diff, so it is admitted here.
    "tests/test-issue-798-topology-flip.sh"
    "tests/test-issue-799-inert-cleanup.sh"
    "tests/test-issue-955-subagent-background-ban.sh"
    "tests/test-issue-846-doc-assertions.sh"
    "tests/test-issue-848-doc-assertions.sh"
    "tests/test-issue-952-wizard-removal.sh"
    # #52 cycle admission — same mechanical scope-guard admission practice as
    # the block above (precedent: 5b01eaf for #51, 26ce222 for #67). #52's
    # own commit touches these four paths (two claim-site doc edits, its
    # cycle-scoped suite, and its manual scenario), and this array is amended
    # to admit them so an unrelated cycle's own diff isn't misattributed.
    "docs/design-rationale.md"
    "docs/teammate-contracts.md"
    "tests/manual/issue-52-manual-scenarios.md"
    "tests/test-issue-52-peer-facilitator-premise.sh"
    # #69 cycle admission — same mechanical scope-guard admission practice as
    # the blocks above (ledger E16 class; precedent: the #52 block).
    ".claude/workflows/architect-deliberation.js"
    "docs/INDEX.md"
    "docs/adr/0018-verification-depth-justification.md"
    "docs/adr/README.md"
    "docs/autoflow-guide.md"
    "docs/evaluation-system.md"
    "docs/maintained-docs.md"
    "test/workflows/run.mjs"
    "tests/test-issue-27-composition-oracle.sh"
    "tests/test-issue-40-doc-assertions.sh"
    "tests/test-issue-59-adoption-evidence-discipline.sh"
    "tests/test-issue-62-sequential-rounds.sh"
    "tests/test-issue-69-verification-depth.sh"
    # #71 cycle admission — same mechanical scope-guard admission practice as
    # the blocks above (ledger E16 class). #71 removes the cycle-digest emitter
    # and the cross-issue recurrence scan; every path its diff touches is
    # admitted here, including the sibling guards amended for the same reason.
    ".claude/agents/autoflow-analyzer.md"
    "docs/cycle-digest.jsonl"
    "docs/improvement-backlog.md"
    "docs/phases/analysis.md"
    "plugin/autoflow/agents/autoflow-analyzer.md"
    "scripts/handoff/emit-cycle-digest.sh"
    "scripts/preflight/scan-cross-issue-recurrence.sh"
    "setup/gen-manifest-hashes.sh"
    "tests/adr-0016-conformance-check.sh"
    "tests/fixtures/cycle-digest-954-at-k.jsonl"
    "tests/fixtures/cycle-digest-954-below-k.jsonl"
    "tests/fixtures/cycle-digest-954-cross-axis.jsonl"
    "tests/fixtures/cycle-digest-954-dedup-window.jsonl"
    "tests/fixtures/cycle-digest-954-dedup.jsonl"
    "tests/fixtures/cycle-digest-954-dual-axis.jsonl"
    "tests/fixtures/cycle-digest-954-out-of-window.jsonl"
    "tests/fixtures/cycle-digest-979-pre-migration-snapshot.jsonl"
    "tests/fixtures/cycle-digest-schema.json"
    "tests/manual/issue-71-manual-scenarios.md"
    "tests/manual/issue-953-manual-scenarios.md"
    "tests/manual/issue-954-manual-scenarios.md"
    "tests/plugin/verify-e2e-dummy-target.sh"
    "tests/plugin/verify-install-into-target.sh"
    "tests/test-issue-1-guard-contract.sh"
    "tests/test-issue-35-phase-marker.sh"
    "tests/test-issue-40-hook-additive.sh"
    "tests/test-issue-42-spawn-mode-contract.sh"
    "tests/test-issue-51-teammate-removal-verdict.sh"
    "tests/test-issue-6-severity-parse-contract.sh"
    "tests/test-issue-7-oracle-hardening.sh"
    "tests/test-issue-71-digest-removal.sh"
    "tests/test-issue-953-cycle-digest.sh"
    "tests/test-issue-954-cross-issue-scan.sh"
    "tests/test-issue-985-doc-assertions.sh"
  )
  BASE55="$(resolve_base_ref 2>/dev/null || true)"
  if [ -n "$BASE55" ]; then
    OUTSIDE_55=""
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      found=no
      for a in "${ALLOWLIST_55[@]}"; do [ "$f" = "$a" ] && { found=yes; break; }; done
      [ "$found" = no ] && OUTSIDE_55="${OUTSIDE_55:+$OUTSIDE_55, }$f"
    done < <(git -C "$PROJECT_ROOT" diff --name-only "${BASE55}...HEAD" 2>/dev/null)
    assert_true "committed-surface-completeness: git diff --name-only vs base contains no file outside the cycle allow-list (Part 5's nine members + ledger E16's scope-guard admissions) (outside: ${OUTSIDE_55:-none})" \
      "[ -z '$OUTSIDE_55' ]"
  else
    assert_true "committed-surface-completeness: a comparison base is resolvable (resolve_base_ref, fail-loud per tests/lib/base-ref.sh contract)" "false"
  fi
else
  assert_true "committed-surface-completeness: tests/lib/base-ref.sh exists" "false"
fi

echo "=============================="
echo "Results: $((PASS + FAIL)) total, $PASS passed, $FAIL failed"
echo "=============================="
[[ $FAIL -eq 0 ]]
