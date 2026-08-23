#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: tests/fixtures/ docs/adr/ .claude/hooks/check-autoflow-gate.sh
# lane: cycle-scoped
# retire-with: #74
# cycle-arm: #74
# out-of-tree-inputs: yes
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: issue #74 — C7 pilot fixture ground truth + verdict predicate
#   (cycle-scoped suite, RED stage 2)
# =============================================================================
# Verification design: .autoflow/issue-74-verification-design.md. Acceptance
# criteria this suite carries: probe-ground-truth, ground-truth-not-handed,
# arm-payload-parity (automated half), arm-substrate-parity (automated half),
# one-tree-witness, pilot-record-completeness, verdict-predicate-derivation,
# predicate-edge-arms, cost-latency-record, adr-0019-record (presence arms),
# adr-0017-untouched, adr-0003-invariant (cycle-scoped DELTA leg),
# fixture-inertness — all branch-independent — plus, since the pilot verdict
# selected Branch A (EQUAL_OR_BETTER, ledger E16/E24-equivalent): the
# hook-prefix-disposition live-hook oracle and the teamcreate-pruned
# repository-wide token sweep. `no-teammate-spawn-path`'s two-part guard and
# `teamcreate-pruned`'s single-file half live as PERMANENT registry entries
# under origin_issue: 74 in tests/fixtures/doc-invariants.json (STATE
# predicates, per docs/doc-invariant-registry.md's two-lane rule), not in this
# suite. `registry-continuity`'s re-pointing of the existing origin_issue 42/43
# entries is intentionally NOT in this suite's scope — see this cycle's report
# to the team lead for why.
#
# RED expectation (this commit — GREEN is landing concurrently; the fixture
# and frozen arm records exist from RED stage 1 / the pilot; ADR-0021 and the
# Branch A hook/CLAUDE.md edits may or may not be present at any given run):
#   FAIL (discriminators, pre-GREEN): adr-0019-record (file absent),
#     verdict-predicate-derivation's ADR-comparison leg, cost-latency-record's
#     ADR-figures sub-check, hook-prefix-disposition arms (pre-edit hook still
#     admits/denies on the old channel), teamcreate-pruned (CLAUDE.md still
#     names TeamCreate at the time this suite was authored).
#   PASS (guards, already true from RED stage 1 / the pilot alone):
#     probe-ground-truth, ground-truth-not-handed, fixture-inertness,
#     one-tree-witness, pilot-record-completeness, predicate-edge-arms
#     (pure evaluator logic, no dependency on ADR-0021),
#     cost-latency-record's frozen-record sub-check, adr-0017-untouched,
#     adr-0003-invariant, arm-payload-parity, arm-substrate-parity.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=tests/lib/base-ref.sh
. "$SCRIPT_DIR/lib/base-ref.sh"

# Cycle #74 change-surface allow-list (cycle-arm: #74) — the paths this cycle's
# PR is allowed to touch vs main; the manifest lint binds the cycle-scoped lane
# to this declared evaluation set.
# shellcheck disable=SC2034
allow_list=(
  ".claude/hooks/check-autoflow-gate.sh"
  ".github/workflows/contract-suites.yml"
  "CLAUDE.md"
  "REUSE.toml"
  "docs/adr/0021-c7-pilot-spawn-mode-result.md"
  "docs/adr/README.md"
  "docs/autoflow-guide.md"
  "docs/gate-matching-standard.md"
  "docs/repo-boundary-rules.md"
  "docs/submodule-common-rules.md"
  "docs/teammate-common-rules.md"
  "docs/teammate-contracts.md"
  "plugin/autoflow/hooks/check-autoflow-gate.sh"
  "setup/manifest.json"
  "tests/fixtures/c7-pilot-arms.json"
  "tests/fixtures/c7-pilot-ground-truth.md"
  "tests/fixtures/c7-pilot/"
  "tests/manual/issue-74-manual-scenarios.md"
  "tests/test-gate-hardening.sh"
  "tests/test-issue-223-schema-hook-contract.sh"
  "tests/test-issue-74-c7-pilot.sh"
)

FIXTURE_DIR="$PROJECT_ROOT/tests/fixtures/c7-pilot"
GROUND_TRUTH="$PROJECT_ROOT/tests/fixtures/c7-pilot-ground-truth.md"
ARMS_JSON="$PROJECT_ROOT/tests/fixtures/c7-pilot-arms.json"
MANUAL_SCENARIOS="$PROJECT_ROOT/tests/manual/issue-74-manual-scenarios.md"
ADR_0019="$PROJECT_ROOT/docs/adr/0021-c7-pilot-spawn-mode-result.md"
HOOK="$PROJECT_ROOT/.claude/hooks/check-autoflow-gate.sh"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
assert() { # assert <desc> <cond-as-shell-test-result:0|nonzero>
  if [ "$2" -eq 0 ]; then pass "$1"; else fail "$1"; fi
}

# =============================================================================
# probe-ground-truth
# =============================================================================
echo "probe-ground-truth"

SUITE_FILE="$FIXTURE_DIR/probe-suite"
CLI_FILE="$FIXTURE_DIR/probe-cli"

# Both step-3 branches are invoked in probe-suite.
if grep -q 'probe-cli" planted' "$SUITE_FILE" 2>/dev/null; then
  pass "probe-ground-truth: probe-suite invokes probe-cli's planted branch"
else
  fail "probe-ground-truth: probe-suite does not invoke probe-cli's planted branch"
fi
if grep -q 'probe-cli" covered' "$SUITE_FILE" 2>/dev/null; then
  pass "probe-ground-truth: probe-suite invokes probe-cli's covered branch"
else
  fail "probe-ground-truth: probe-suite does not invoke probe-cli's covered branch"
fi

# Exactly one probe_assert helper is defined.
ASSERT_DEFS=$(grep -c '^probe_assert() {' "$SUITE_FILE" 2>/dev/null || true)
assert "probe-ground-truth: exactly one probe_assert() definition" \
  $([ "${ASSERT_DEFS:-0}" -eq 1 ] && echo 0 || echo 1)

# Lines that actually INVOKE probe_assert (the definition line and comment
# lines that merely mention the name are excluded) — a real invocation line
# has the shape `probe_assert "<arg>" ...` at statement position.
invoking_lines() {
  grep -E '^[[:space:]]*probe_assert[[:space:]]+"' "$SUITE_FILE" 2>/dev/null
}
INVOKE_LINES="$(invoking_lines)"

# Covered branch's sentinel appears as an argument on an invoking line.
if printf '%s\n' "$INVOKE_LINES" | grep -q 'PROBE_S3_COVERED'; then
  pass "probe-ground-truth: PROBE_S3_COVERED appears on a probe_assert invocation line (covered)"
else
  fail "probe-ground-truth: PROBE_S3_COVERED does not appear on any probe_assert invocation line"
fi

# Planted branch's sentinel appears on NO invoking line (exercised, unasserted).
if printf '%s\n' "$INVOKE_LINES" | grep -q 'PROBE_S3_PLANTED'; then
  fail "probe-ground-truth: PROBE_S3_PLANTED appears on a probe_assert invocation line (should be exercised but unasserted)"
else
  pass "probe-ground-truth: PROBE_S3_PLANTED appears on no probe_assert invocation line"
fi

# Mock-boundary contract comparison — step4-planted pair: argv shape (dispatch
# labels) held matching, error-path/exit-status diverging.
real_case_labels() { grep -oE '^\s*[a-zA-Z_][a-zA-Z0-9_]*\)' "$1" 2>/dev/null | tr -d ' )' | sort -u; }
REAL_LABELS=$(real_case_labels "$FIXTURE_DIR/real-tool")
MOCK_LABELS=$(real_case_labels "$FIXTURE_DIR/mock-real-tool/real-tool")
assert "probe-ground-truth: mock-real-tool/real-tool argv dispatch shape matches real-tool" \
  $([ "$REAL_LABELS" = "$MOCK_LABELS" ] && echo 0 || echo 1)

REAL_RUN_OUT=$("$FIXTURE_DIR/real-tool" run 2>/dev/null); REAL_RUN_EXIT=$?
MOCK_RUN_OUT=$("$FIXTURE_DIR/mock-real-tool/real-tool" run 2>/dev/null); MOCK_RUN_EXIT=$?
assert "probe-ground-truth: real-tool / mock double agree on the non-error path (run)" \
  $([ "$REAL_RUN_EXIT" -eq "$MOCK_RUN_EXIT" ] && [ "$REAL_RUN_OUT" = "$MOCK_RUN_OUT" ] && echo 0 || echo 1)

"$FIXTURE_DIR/real-tool" bogus >/dev/null 2>&1; REAL_ERR_EXIT=$?
"$FIXTURE_DIR/mock-real-tool/real-tool" bogus >/dev/null 2>&1; MOCK_ERR_EXIT=$?
assert "probe-ground-truth: mock-real-tool/real-tool DIVERGES from real-tool on the error path (exit $REAL_ERR_EXIT vs $MOCK_ERR_EXIT)" \
  $([ "$REAL_ERR_EXIT" -ne "$MOCK_ERR_EXIT" ] && echo 0 || echo 1)

# step4-clean pair: matches in all four dimensions.
REAL_B_LABELS=$(real_case_labels "$FIXTURE_DIR/real-tool-b")
MOCK_B_LABELS=$(real_case_labels "$FIXTURE_DIR/mock-real-tool-b/real-tool-b")
assert "probe-ground-truth: mock-real-tool-b/real-tool-b argv dispatch shape matches real-tool-b" \
  $([ "$REAL_B_LABELS" = "$MOCK_B_LABELS" ] && echo 0 || echo 1)

"$FIXTURE_DIR/real-tool-b" run >/tmp/rt_b_run.$$ 2>&1; REAL_B_RUN_EXIT=$?
"$FIXTURE_DIR/mock-real-tool-b/real-tool-b" run >/tmp/mock_b_run.$$ 2>&1; MOCK_B_RUN_EXIT=$?
REAL_B_RUN_OUT=$(cat /tmp/rt_b_run.$$); MOCK_B_RUN_OUT=$(cat /tmp/mock_b_run.$$)
rm -f /tmp/rt_b_run.$$ /tmp/mock_b_run.$$
assert "probe-ground-truth: real-tool-b / mock double MATCH on the non-error path (run)" \
  $([ "$REAL_B_RUN_EXIT" -eq "$MOCK_B_RUN_EXIT" ] && [ "$REAL_B_RUN_OUT" = "$MOCK_B_RUN_OUT" ] && echo 0 || echo 1)

"$FIXTURE_DIR/real-tool-b" bogus >/tmp/rt_b_err.$$ 2>&1; REAL_B_ERR_EXIT=$?
"$FIXTURE_DIR/mock-real-tool-b/real-tool-b" bogus >/tmp/mock_b_err.$$ 2>&1; MOCK_B_ERR_EXIT=$?
REAL_B_ERR_OUT=$(cat /tmp/rt_b_err.$$); MOCK_B_ERR_OUT=$(cat /tmp/mock_b_err.$$)
rm -f /tmp/rt_b_err.$$ /tmp/mock_b_err.$$
assert "probe-ground-truth: real-tool-b / mock double MATCH on the error path (exit + message)" \
  $([ "$REAL_B_ERR_EXIT" -eq "$MOCK_B_ERR_EXIT" ] && [ "$REAL_B_ERR_OUT" = "$MOCK_B_ERR_OUT" ] && echo 0 || echo 1)

# =============================================================================
# ground-truth-not-handed
# =============================================================================
echo "ground-truth-not-handed"
assert "ground-truth-not-handed: c7-pilot-ground-truth.md exists as a SIBLING of tests/fixtures/c7-pilot/" \
  $([ -f "$GROUND_TRUTH" ] && echo 0 || echo 1)
assert "ground-truth-not-handed: the ground-truth file is NOT inside the handed tree tests/fixtures/c7-pilot/" \
  $([ ! -f "$FIXTURE_DIR/c7-pilot-ground-truth.md" ] && echo 0 || echo 1)

# =============================================================================
# fixture-inertness
# =============================================================================
echo "fixture-inertness"

SPEC_FILES=$(find "$FIXTURE_DIR" -type f \( -name '*.sh' -o -name '*.bats' \) 2>/dev/null | wc -l | tr -d ' ')
assert "fixture-inertness: no *.sh / *.bats file exists under tests/fixtures/c7-pilot/" \
  $([ "$SPEC_FILES" -eq 0 ] && echo 0 || echo 1)

# Every executable file under the fixture is extensionless (tests/issue-25/mock-gh/gh precedent).
EXT_EXECUTABLES=0
while IFS= read -r f; do
  base="$(basename "$f")"
  case "$base" in *.*) EXT_EXECUTABLES=$((EXT_EXECUTABLES + 1)) ;; esac
done < <(find "$FIXTURE_DIR" -type f -perm -u+x 2>/dev/null)
assert "fixture-inertness: every executable fixture file is extensionless" \
  $([ "$EXT_EXECUTABLES" -eq 0 ] && echo 0 || echo 1)

# The real coverage lint does not enumerate anything under the fixture tree
# (real execution, no double).
LINT_OUT="$(bash "$PROJECT_ROOT/scripts/test/check-suite-ci-coverage.sh" 2>&1)"
LINT_EXIT=$?
assert "fixture-inertness: scripts/test/check-suite-ci-coverage.sh exits 0 over the real tree" \
  $([ "$LINT_EXIT" -eq 0 ] && echo 0 || echo 1)
if printf '%s' "$LINT_OUT" | grep -q 'tests/fixtures/c7-pilot'; then
  fail "fixture-inertness: coverage lint output names a path under tests/fixtures/c7-pilot/ (should be silently excluded by construction)"
else
  pass "fixture-inertness: coverage lint output names no path under tests/fixtures/c7-pilot/"
fi

# =============================================================================
# one-tree-witness
# =============================================================================
echo "one-tree-witness"

if [ -f "$ARMS_JSON" ]; then
  TREE_COUNT=$(jq '[.tree] | length' "$ARMS_JSON" 2>/dev/null || echo 0)
  TREE_VAL=$(jq -r '.tree // empty' "$ARMS_JSON" 2>/dev/null)
  assert "one-tree-witness: frozen union carries exactly one top-level 'tree' value" \
    $([ "$TREE_COUNT" -eq 1 ] && [ -n "$TREE_VAL" ] && echo 0 || echo 1)

  if [ -n "${TREE_VAL:-}" ] && git -C "$PROJECT_ROOT" cat-file -e "${TREE_VAL}^{commit}" 2>/dev/null; then
    pass "one-tree-witness: 'tree' resolves to a real commit object ($TREE_VAL)"
  else
    fail "one-tree-witness: 'tree' does not resolve to a real commit object"
  fi

  MISMATCHED=$(jq -r --arg t "$TREE_VAL" '[.records[] | select(.observed_head != $t)] | length' "$ARMS_JSON" 2>/dev/null || echo "err")
  assert "one-tree-witness: every record's observed_head equals the frozen tree" \
    $([ "$MISMATCHED" = "0" ] && echo 0 || echo 1)
else
  fail "one-tree-witness: tests/fixtures/c7-pilot-arms.json does not exist"
fi

# =============================================================================
# pilot-record-completeness
# =============================================================================
echo "pilot-record-completeness"

if [ -f "$ARMS_JSON" ]; then
  R_DECLARED=$(jq -r '.replicates // empty' "$ARMS_JSON")
  assert "pilot-record-completeness: declared replicates == 3 (the fixed constant R)" \
    $([ "$R_DECLARED" = "3" ] && echo 0 || echo 1)

  BAD_OUTCOMES=$(jq -r '
    [.records[] | .outcomes | to_entries[] | select(.value != "detected" and .value != "clean" and .value != "not-run")] | length
  ' "$ARMS_JSON" 2>/dev/null || echo "err")
  assert "pilot-record-completeness: every outcomes value is detected|clean|not-run" \
    $([ "$BAD_OUTCOMES" = "0" ] && echo 0 || echo 1)

  MISSING_FIELDS=$(jq -r '
    [.records[] | select((has("iteration_set")|not) or (has("observed_head")|not)
      or (has("delivery")|not) or (has("latency_seconds")|not) or (has("turns")|not))] | length
  ' "$ARMS_JSON" 2>/dev/null || echo "err")
  assert "pilot-record-completeness: every record carries iteration_set/observed_head/delivery/latency_seconds/turns" \
    $([ "$MISSING_FIELDS" = "0" ] && echo 0 || echo 1)

  for arm in named direct; do
    REPS=$(jq -r --arg a "$arm" '[.records[] | select(.arm==$a) | .replicate] | sort | @csv' "$ARMS_JSON" 2>/dev/null)
    assert "pilot-record-completeness: arm '$arm' carries exactly replicates 1,2,3 once each (got: $REPS)" \
      $([ "$REPS" = "1,2,3" ] && echo 0 || echo 1)
  done
else
  fail "pilot-record-completeness: tests/fixtures/c7-pilot-arms.json does not exist"
fi

# =============================================================================
# cost-latency-record (ADR-0017 C8) — existence only, no value assertion
# =============================================================================
echo "cost-latency-record"

if [ -f "$ARMS_JSON" ]; then
  MISSING_C8=$(jq -r '[.records[] | select((has("latency_seconds")|not) or (has("turns")|not))] | length' "$ARMS_JSON" 2>/dev/null || echo "err")
  assert "cost-latency-record: every frozen record carries latency_seconds and turns" \
    $([ "$MISSING_C8" = "0" ] && echo 0 || echo 1)
fi
if [ -f "$ADR_0019" ] && grep -qi 'latency' "$ADR_0019" && grep -qi 'turn' "$ADR_0019"; then
  pass "cost-latency-record: ADR-0021 states the C8 latency/turn figures"
else
  fail "cost-latency-record: ADR-0021 does not (yet) state the C8 figures"
fi

# =============================================================================
# verdict-predicate-derivation
# =============================================================================
echo "verdict-predicate-derivation"

read -r -d '' VERDICT_JQ <<'JQEOF' || true
def rate($records; $arm; $field):
  ([$records[] | select(.arm==$arm) | .outcomes[$field]]) as $v
  | if ($v | length) == 0 then null
    else ($v | map(select(. == "detected")) | length) / ($v | length)
    end;
. as $root
| ($root.records) as $r
| {
    dr_named_3: rate($r; "named"; "step3_planted"),
    fp_named_3: rate($r; "named"; "step3_clean"),
    dr_named_4: rate($r; "named"; "step4_planted"),
    fp_named_4: rate($r; "named"; "step4_clean"),
    dr_direct_3: rate($r; "direct"; "step3_planted"),
    fp_direct_3: rate($r; "direct"; "step3_clean"),
    dr_direct_4: rate($r; "direct"; "step4_planted"),
    fp_direct_4: rate($r; "direct"; "step4_clean"),
  }
| .disc3 = ((.dr_named_3 - .fp_named_3) > 0)
| .disc4 = ((.dr_named_4 - .fp_named_4) > 0)
| .verdict = (
    if (.disc3 | not) or (.disc4 | not) then "INCONCLUSIVE"
    elif (.dr_direct_3 >= .dr_named_3 and .fp_direct_3 <= .fp_named_3
          and .dr_direct_4 >= .dr_named_4 and .fp_direct_4 <= .fp_named_4) then "EQUAL_OR_BETTER"
    else "INFERIOR"
    end)
JQEOF

if [ -f "$ARMS_JSON" ]; then
  RECOMPUTED_VERDICT=$(jq -r "$VERDICT_JQ | .verdict" "$ARMS_JSON" 2>/dev/null)
  echo "  (info) recomputed verdict from frozen records: ${RECOMPUTED_VERDICT:-<jq error>}"
  if [ -f "$ADR_0019" ] && [ -n "${RECOMPUTED_VERDICT:-}" ] && grep -q "$RECOMPUTED_VERDICT" "$ADR_0019"; then
    pass "verdict-predicate-derivation: ADR-0021 states the same verdict the suite recomputes ($RECOMPUTED_VERDICT)"
  else
    fail "verdict-predicate-derivation: ADR-0021 does not (yet) state the recomputed verdict ($RECOMPUTED_VERDICT)"
  fi
else
  fail "verdict-predicate-derivation: no frozen records to recompute from"
fi

# =============================================================================
# predicate-edge-arms — the evaluator on synthetic branches, independent of
# the real pilot data (pure logic; no dependency on GREEN's ADR-0021).
# =============================================================================
echo "predicate-edge-arms"

_q() { echo "$1" | sed -E 's/([^,]+)/"\1"/g'; }
mk_arm() { # mk_arm <arm> <s3p csv> <s3c csv> <s4p csv> <s4c csv>
  jq -n --arg arm "$1" \
        --argjson s3p "[$(_q "$2")]" --argjson s3c "[$(_q "$3")]" \
        --argjson s4p "[$(_q "$4")]" --argjson s4c "[$(_q "$5")]" \
    '[range(0; ($s3p|length)) as $i | {arm:$arm, replicate:($i+1),
       outcomes:{step3_planted:$s3p[$i], step3_clean:$s3c[$i],
                  step4_planted:$s4p[$i], step4_clean:$s4c[$i]}}]'
}
edge_verdict() { # edge_verdict <named-json-array> <direct-json-array>
  jq -n --argjson n "$1" --argjson d "$2" '{records: ($n + $d)}' | jq -r "$VERDICT_JQ | .verdict"
}

# (a) baseline that never detects -> margin 0-0 not > 0 -> INCONCLUSIVE
N_A=$(mk_arm named "clean,clean,clean" "clean,clean,clean" "clean,clean,clean" "clean,clean,clean")
D_A=$(mk_arm direct "clean,clean,clean" "clean,clean,clean" "clean,clean,clean" "clean,clean,clean")
V_A=$(edge_verdict "$N_A" "$D_A")
assert "predicate-edge-arms (a): never-detecting baseline -> INCONCLUSIVE (got $V_A)" \
  $([ "$V_A" = "INCONCLUSIVE" ] && echo 0 || echo 1)

# (b) saturated baseline: detected on every condition (both arms) -> margin 1-1 not > 0 -> INCONCLUSIVE, not EQUAL_OR_BETTER
N_B=$(mk_arm named "detected,detected,detected" "detected,detected,detected" "detected,detected,detected" "detected,detected,detected")
D_B=$(mk_arm direct "detected,detected,detected" "detected,detected,detected" "detected,detected,detected" "detected,detected,detected")
V_B=$(edge_verdict "$N_B" "$D_B")
assert "predicate-edge-arms (b): saturated baseline (detect_rate=fp_rate=1) -> INCONCLUSIVE, not EQUAL_OR_BETTER (got $V_B)" \
  $([ "$V_B" = "INCONCLUSIVE" ] && echo 0 || echo 1)

# (c) floor: named detects 1/3, 0 fp; direct ties -> EQUAL_OR_BETTER (thin-evidence branch, deliberately admitted)
N_C=$(mk_arm named "detected,clean,clean" "clean,clean,clean" "detected,clean,clean" "clean,clean,clean")
D_C=$(mk_arm direct "detected,clean,clean" "clean,clean,clean" "detected,clean,clean" "clean,clean,clean")
V_C=$(edge_verdict "$N_C" "$D_C")
assert "predicate-edge-arms (c): floor margin (1/3 detect, 0 fp), direct ties -> EQUAL_OR_BETTER (got $V_C)" \
  $([ "$V_C" = "EQUAL_OR_BETTER" ] && echo 0 || echo 1)

# (d) strictly better direct arm -> EQUAL_OR_BETTER
N_D=$(mk_arm named "detected,clean,clean" "clean,clean,clean" "detected,clean,clean" "clean,clean,clean")
D_D=$(mk_arm direct "detected,detected,detected" "clean,clean,clean" "detected,detected,detected" "clean,clean,clean")
V_D=$(edge_verdict "$N_D" "$D_D")
assert "predicate-edge-arms (d): strictly-better direct arm -> EQUAL_OR_BETTER (got $V_D)" \
  $([ "$V_D" = "EQUAL_OR_BETTER" ] && echo 0 || echo 1)

# (e) direct worse only on false positives -> INFERIOR
N_E=$(mk_arm named "detected,detected,detected" "clean,clean,clean" "detected,detected,detected" "clean,clean,clean")
D_E=$(mk_arm direct "detected,detected,detected" "detected,clean,clean" "detected,detected,detected" "clean,clean,clean")
V_E=$(edge_verdict "$N_E" "$D_E")
assert "predicate-edge-arms (e): direct worse on false positives only -> INFERIOR (got $V_E)" \
  $([ "$V_E" = "INFERIOR" ] && echo 0 || echo 1)

# (f) cross-step split: direct better on step3, worse on step4 -> INFERIOR (pins the "for every s" quantifier)
N_F=$(mk_arm named "detected,clean,clean" "clean,clean,clean" "detected,detected,detected" "clean,clean,clean")
D_F=$(mk_arm direct "detected,detected,detected" "clean,clean,clean" "clean,clean,clean" "clean,clean,clean")
V_F=$(edge_verdict "$N_F" "$D_F")
assert "predicate-edge-arms (f): cross-step split (better step3, worse step4) -> INFERIOR (got $V_F)" \
  $([ "$V_F" = "INFERIOR" ] && echo 0 || echo 1)

# =============================================================================
# adr-0019-record (presence arms)
# =============================================================================
echo "adr-0019-record"

if [ -f "$ADR_0019" ]; then
  pass "adr-0019-record: docs/adr/0021-c7-pilot-spawn-mode-result.md exists"
  ADR_BODY="$(cat "$ADR_0019")"
  # ADR heading/value convention (docs/adr/0000-adr-template.md): "## Status"
  # heading, then the value on its own line below (not inline on the heading
  # or in "Status: X" prose form). Capture the context first (docs/submodule-common-rules.md
  # > Testing Standards > SIGPIPE-safe assertion pipes): piping a streaming
  # context producer (grep -A) directly into a short-circuiting consumer
  # (grep -q) risks SIGPIPE under pipefail, banned repo-wide by
  # tests/test-issue-964-sigpipe-safe-pipes.sh AC2-A.
  STATUS_CTX="$(printf '%s' "$ADR_BODY" | grep -A2 -E '^## Status\b')"
  assert "adr-0019-record: Status is Proposed" \
    $(printf '%s\n' "$STATUS_CTX" | grep -qE '^Proposed$' && echo 0 || echo 1)
  assert "adr-0019-record: states the discriminating check" \
    $(printf '%s' "$ADR_BODY" | grep -qi 'discriminating' && echo 0 || echo 1)
  assert "adr-0019-record: states per-arm detection/false-positive rates" \
    $(printf '%s' "$ADR_BODY" | grep -qi 'detect_rate\|detection rate' && echo 0 || echo 1)
  assert "adr-0019-record: states that token cost was not measured, and why" \
    $(printf '%s' "$ADR_BODY" | grep -qi 'token' && echo 0 || echo 1)
  assert "adr-0019-record departure 1/3: states the C7 literal-form substitution (seeded probe)" \
    $(printf '%s' "$ADR_BODY" | grep -qi 'seeded probe\|literal.*form\|substitut' && echo 0 || echo 1)
  assert "adr-0019-record departure 2/3: states the external-validity limit of the fixture substrate" \
    $(printf '%s' "$ADR_BODY" | grep -qi 'external validity\|fixture substrate' && echo 0 || echo 1)
  assert "adr-0019-record departure 3/3: states the residual channel-intrinsic prompt-position asymmetry" \
    $(printf '%s' "$ADR_BODY" | grep -qi 'prompt.position\|position asymmetry\|channel.intrinsic' && echo 0 || echo 1)
else
  fail "adr-0019-record: docs/adr/0021-c7-pilot-spawn-mode-result.md does not exist"
fi

# =============================================================================
# adr-0017-untouched (DELTA guard, cycle-scoped)
# =============================================================================
echo "adr-0017-untouched"

if BASE74="$(resolve_base_ref 2>/dev/null)"; then
  ADR17_DIFF=$(git -C "$PROJECT_ROOT" diff --name-only "$BASE74"...HEAD -- docs/adr/0017-teammate-removal-feasibility.md 2>/dev/null)
  assert "adr-0017-untouched: this cycle's diff does not touch docs/adr/0017-teammate-removal-feasibility.md" \
    $([ -z "$ADR17_DIFF" ] && echo 0 || echo 1)
else
  fail "adr-0017-untouched: resolve_base_ref could not resolve a comparison base (fail-loud, per tests/lib/base-ref.sh contract)"
fi

# =============================================================================
# adr-0003-invariant (cycle-scoped DELTA leg — the permanent registry leg is
# out of this suite's scope, per §1 two-lane partition)
# =============================================================================
echo "adr-0003-invariant"

if [ -n "${BASE74:-}" ]; then
  ADR3_DIFF=$(git -C "$PROJECT_ROOT" diff --name-only "$BASE74"...HEAD -- docs/adr/0003-autoflow-ends-at-handoff.md 2>/dev/null)
  assert "adr-0003-invariant: this cycle's diff does not touch docs/adr/0003-autoflow-ends-at-handoff.md" \
    $([ -z "$ADR3_DIFF" ] && echo 0 || echo 1)
else
  fail "adr-0003-invariant: no comparison base resolvable"
fi

# =============================================================================
# arm-payload-parity (automated half — admissibility + record shape)
# =============================================================================
echo "arm-payload-parity"

# Record-shape half: exactly the two arm labels, equal replicate sets (already
# checked structurally above under pilot-record-completeness — restated here
# as the criterion's own name for traceability).
if [ -f "$ARMS_JSON" ]; then
  ARM_LABELS=$(jq -r '[.records[].arm] | unique | sort | @csv' "$ARMS_JSON" 2>/dev/null)
  assert "arm-payload-parity: frozen records carry exactly the two arm labels 'direct','named'" \
    $([ "$ARM_LABELS" = '"direct","named"' ] && echo 0 || echo 1)
fi

# Admissibility half: live-hook oracle. Both arm payloads (Feature §4 *Arm
# payloads*) resolve to the testing role and are admitted under a passed
# GATE:PLAN state. This is a claim about the pilot's OWN admissibility at the
# time it ran — i.e. against the hook AS IT STOOD AT THE FROZEN tree, not
# against a possibly-since-migrated working-tree hook (arm-substrate-parity's
# same frozen-tree discipline applies here for the identical reason: Branch A
# may have already landed in this working tree by the time this suite runs).
PASSING74=$(mktemp -d)
mkdir -p "$PASSING74/.autoflow"
cat > "$PASSING74/.autoflow/issue-74.json" <<'EOF'
{ "active": true, "issue": "#74",
  "phases": {
    "gate_hypothesis_cause": {"verdict":"skipped (feat issue)"},
    "gate_plan":    {"scores":{"a":{"score":8},"b":{"score":8}}} } }
EOF
trap 'rm -rf "$PASSING74"' EXIT

FROZEN_HOOK=""
if [ -f "$ARMS_JSON" ]; then
  TREE_FOR_HOOK="$(jq -r '.tree // empty' "$ARMS_JSON" 2>/dev/null)"
  if [ -n "$TREE_FOR_HOOK" ]; then
    FROZEN_HOOK="$(mktemp)"
    if git -C "$PROJECT_ROOT" show "${TREE_FOR_HOOK}:.claude/hooks/check-autoflow-gate.sh" > "$FROZEN_HOOK" 2>/dev/null; then
      chmod +x "$FROZEN_HOOK"
    else
      FROZEN_HOOK=""
    fi
  fi
fi
trap 'rm -rf "$PASSING74"; [ -n "$FROZEN_HOOK" ] && rm -f "$FROZEN_HOOK"' EXIT

agent_json_named() { printf '{"tool_name":"Agent","tool_input":{"team_name":"issue-74-cycle","name":%s,"prompt":"pilot arm","model":"sonnet"}}' "$(printf '%s' "$1" | jq -Rs .)"; }
agent_json_direct() { printf '{"tool_name":"Agent","tool_input":{"subagent_type":"autoflow-tester","prompt":"pilot arm","model":"sonnet"}}'; }

run_hook_oracle() { # run_hook_oracle <expected_exit> <desc> <json>
  local expected="$1" desc="$2" json="$3" actual
  if [ -z "$FROZEN_HOOK" ]; then
    fail "arm-payload-parity: $desc — could not extract the frozen-tree hook to evaluate against"
    return
  fi
  actual=$(printf '%s' "$json" | CLAUDE_PROJECT_DIR="$PASSING74" bash "$FROZEN_HOOK" >/dev/null 2>&1; echo $?)
  assert "arm-payload-parity: $desc (exit $actual, expected $expected)" \
    $([ "$actual" = "$expected" ] && echo 0 || echo 1)
}
run_hook_oracle 0 "named arm payload (team_name+name=test-c7-baseline-r1) admitted under passed GATE:PLAN" \
  "$(agent_json_named 'test-c7-baseline-r1')"
run_hook_oracle 0 "direct arm payload (subagent_type=autoflow-tester) admitted under passed GATE:PLAN" \
  "$(agent_json_direct)"

# =============================================================================
# arm-substrate-parity (automated half — text identity against the frozen tree)
# =============================================================================
echo "arm-substrate-parity"

if [ -f "$ARMS_JSON" ] && [ -f "$MANUAL_SCENARIOS" ]; then
  TREE_VAL="$(jq -r '.tree // empty' "$ARMS_JSON" 2>/dev/null)"
  if [ -n "$TREE_VAL" ]; then
    FROZEN_TESTER_MD="$(git -C "$PROJECT_ROOT" show "${TREE_VAL}:.claude/agents/autoflow-tester.md" 2>/dev/null)"
    if [ -n "$FROZEN_TESTER_MD" ]; then
      # Duty lines this criterion pins: step-3 check, iteration-set
      # re-enumeration, step-4 fidelity check — each asserted present,
      # verbatim, in the manual scenario's recorded named-arm prompt block.
      DUTY_STEP3=$(printf '%s' "$FROZEN_TESTER_MD" | grep -F 'Perform the VERIFY minimal-implementation check on the implementation diff:')
      DUTY_ITERSET=$(printf '%s' "$FROZEN_TESTER_MD" | grep -F 're-enumerate the iteration set from the test tree at HEAD')
      DUTY_STEP4=$(printf '%s' "$FROZEN_TESTER_MD" | grep -F 'Perform the VERIFY mock-boundary fidelity check over that set:')
      for pair in "step-3 duty:$DUTY_STEP3" "iteration-set re-enumeration duty:$DUTY_ITERSET" "step-4 duty:$DUTY_STEP4"; do
        label="${pair%%:*}"; needle="${pair#*:}"
        if [ -n "$needle" ] && grep -qF -- "$needle" "$MANUAL_SCENARIOS"; then
          pass "arm-substrate-parity: manual scenario carries the $label verbatim from the frozen tree"
        else
          fail "arm-substrate-parity: manual scenario is missing (or diverges from) the $label at the frozen tree"
        fi
      done
    else
      fail "arm-substrate-parity: could not read .claude/agents/autoflow-tester.md at the frozen tree $TREE_VAL"
    fi
  else
    fail "arm-substrate-parity: no frozen tree value to pin against"
  fi
else
  fail "arm-substrate-parity: tests/fixtures/c7-pilot-arms.json or the manual scenario document is missing"
fi
assert "arm-substrate-parity: the manual scenario records the direct arm's subagent_type as autoflow-tester" \
  $(grep -qF '"subagent_type": "autoflow-tester"' "$MANUAL_SCENARIOS" 2>/dev/null && echo 0 || echo 1)

# =============================================================================
# hook-prefix-disposition (Branch A only) — the role-prefix declaration
# channel is removed jointly with this slice (ADR-0017 :135-140). Live-hook
# oracle over the REAL .claude/hooks/check-autoflow-gate.sh.
# =============================================================================
echo "hook-prefix-disposition"

run_hook_prefix() { # run_hook_prefix <expected_exit> <desc> <json>
  local expected="$1" desc="$2" json="$3" actual
  actual=$(printf '%s' "$json" | CLAUDE_PROJECT_DIR="$PASSING74" bash "$HOOK" >/dev/null 2>&1; echo $?)
  assert "hook-prefix-disposition: $desc (exit $actual, expected $expected)" \
    $([ "$actual" = "$expected" ] && echo 0 || echo 1)
}
agent_json_name_only() { printf '{"tool_name":"Agent","tool_input":{"team_name":"issue-74-cycle","name":"test-hookdisp-r1","prompt":"x","model":"sonnet"}}'; }
agent_json_subtype_only() { printf '{"tool_name":"Agent","tool_input":{"subagent_type":"autoflow-tester","prompt":"x","model":"sonnet"}}'; }
agent_json_mixed() { printf '{"tool_name":"Agent","tool_input":{"team_name":"issue-74-cycle","name":"test-hookdisp-r1","subagent_type":"autoflow-tester","prompt":"x","model":"sonnet"}}'; }

run_hook_prefix 2 "team payload carrying only name:'test-…' no longer resolves to a role -> denied as undeclared" \
  "$(agent_json_name_only)"
run_hook_prefix 0 "subagent_type:autoflow-tester (no name) remains admitted subject to GATE:PLAN" \
  "$(agent_json_subtype_only)"
run_hook_prefix 2 "a mixed payload (name + subagent_type both present) stays denied" \
  "$(agent_json_mixed)"

# H4 (VERIFY step-3 coverage) — the deny-message text itself names the
# retired channel and the drop-them remediation; the exit-code-only arms
# above cannot distinguish this from a generic undeclared-spawn denial.
HOOK_DENY_STDERR="$(printf '%s' "$(agent_json_mixed)" | CLAUDE_PROJECT_DIR="$PASSING74" bash "$HOOK" 2>&1 >/dev/null)"
assert "hook-prefix-disposition: deny message names the retired team-spawn channel and the drop-them remediation (H4)" \
  $(printf '%s' "$HOOK_DENY_STDERR" | grep -qF 'the team-spawn channel is retired and a name-carrying payload is denied even with a valid subagent_type' && echo 0 || echo 1)

# =============================================================================
# teamcreate-pruned (Branch A only) — repository-wide token sweep. The
# permanent registry entry 74-teamcreate-pruned-token-absent covers CLAUDE.md
# alone; this arm confirms no OTHER tracked reference is a live (prescriptive)
# reference. docs/adr/0017-teammate-removal-feasibility.md and
# docs/doc-invariant-registry.md legitimately discuss the token as their own
# subject (ADR-0017 Q4; the registry's issue-#74 migration-provenance
# disposition rows) and are excluded by name, not by pattern — the former per
# adr-0017-untouched's own guarantee that file is unedited, the latter because
# a disposition row naming a retired literal is exactly what this suite's own
# retirement rows do (self-reference is unavoidable when documenting a
# retirement).
# =============================================================================
echo "teamcreate-pruned"

TEAMCREATE_HITS="$(git -C "$PROJECT_ROOT" grep -l 'TeamCreate' -- ':!docs/adr/0017-teammate-removal-feasibility.md' ':!docs/doc-invariant-registry.md' ':!tests/test-issue-74-c7-pilot.sh' ':!tests/fixtures/doc-invariants.json' 2>/dev/null || true)"
if [ -z "$TEAMCREATE_HITS" ]; then
  pass "teamcreate-pruned: no live tracked reference to TeamCreate outside the two documents that legitimately discuss it as a retired subject"
else
  fail "teamcreate-pruned: live TeamCreate reference(s) remain: $(printf '%s' "$TEAMCREATE_HITS" | tr '\n' ' ')"
fi

# =============================================================================
# sendmessage-pruned (Branch A only) — repository-wide token sweep mirroring
# teamcreate-pruned, scoped to documentation (tests/** and .autoflow/** are
# the verification apparatus and ledger/manual-scenario evidence, outside
# this sweep's scope by design — a test file legitimately asserts ABOUT
# SendMessage without prescribing its use, and a manual-scenario document is
# a historical record, not a live instruction). Within docs+CLAUDE.md,
# excludes the sites verified to be legitimately descriptive (a retained
# measurement or rationale, not an instruction to a current role):
# CLAUDE.md L122/L139 (states the channel is "no longer used", and explains a
# runtime injection behavior as design rationale for Deliberation Isolation —
# neither instructs a role to call it), docs/adr/0017-*.md (own-subject
# discussion) and docs/doc-invariant-registry.md (disposition-row
# self-reference, same rationale as teamcreate-pruned).
#
# docs/teammate-common-rules.md is NOT whole-file excluded (a file-level
# exclusion would leave future drift in that file invisible) — it is
# LINE-LEVEL swept: every `SendMessage`-carrying line in the file must be the
# retained #40 delivery-loss measurement (L129), identified by its own
# distinctive substring, not by line number (line numbers drift). Any other
# `SendMessage`-carrying line in that file is a residual.
#
# docs/submodule-common-rules.md is DELIBERATELY NOT excluded at all: its
# Reporting Format section (`or to another teammate via SendMessage`) named a
# teammate-to-teammate mailbox path that CLAUDE.md > Communication — Agent
# Teams now states does not exist ("There is no team to create, no mailbox,
# and no persistent teammate") — the residual this sweep already caught once
# (fixed at 99e22a9); leaving the file swept catches any regression.
# =============================================================================
echo "sendmessage-pruned"

TCR_FILE="$PROJECT_ROOT/docs/teammate-common-rules.md"
TCR_RESIDUAL_LINES=""
if [ -f "$TCR_FILE" ]; then
  TCR_RESIDUAL_LINES="$(grep -F 'SendMessage' "$TCR_FILE" | grep -vF 'That measurement is the case for the migration and is retained here for that reason' || true)"
fi
assert "sendmessage-pruned: docs/teammate-common-rules.md carries no SendMessage line other than the retained #40 evidence (L129)" \
  $([ -z "$TCR_RESIDUAL_LINES" ] && echo 0 || echo 1)

SENDMESSAGE_HITS="$(git -C "$PROJECT_ROOT" grep -l 'SendMessage' -- ':!tests/**' ':!.autoflow/**' ':!docs/adr/0017-teammate-removal-feasibility.md' ':!docs/doc-invariant-registry.md' ':!docs/teammate-common-rules.md' ':!CLAUDE.md' 2>/dev/null || true)"
if [ -z "$SENDMESSAGE_HITS" ]; then
  pass "sendmessage-pruned: no live tracked reference to SendMessage outside the documents verified to legitimately discuss it"
else
  fail "sendmessage-pruned: live SendMessage reference(s) remain outside the verified-legitimate set: $(printf '%s' "$SENDMESSAGE_HITS" | tr '\n' ' ')"
fi

echo "=============================="
echo "Results: $((PASS + FAIL)) total, $PASS passed, $FAIL failed"
echo "=============================="
[[ $FAIL -eq 0 ]]
