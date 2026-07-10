#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: cross-issue complaint-class recurrence scan — Issue #954
# =============================================================================
# Tier-1 scripted assertion suite per verification design
# (.autoflow/issue-954-verification-design.md). Docs + ops + shell-script
# change (no jest, no npm) — mirrors tests/test-issue-953-cycle-digest.sh /
# tests/test-issue-949-manifest-regen-doc.sh: assert_true/assert_false over
# grep/awk section extraction + jq + git + direct script invocation on
# fixture digests in an isolated temp copy of the repo.
#
# Scope (verification design §1):
#   AC1 — PREFLIGHT step 1.5 wording (placement, model:"sonnet",
#         autoflow-analyzer role, single-shot/no-loop), M/K given as literal
#         constants, script boundedness (no unbounded loop).
#   AC2 — durable source = docs/cycle-digest.jsonl only, explicit negative
#         clause against reading .autoflow/, script's only corpus read is
#         the digest, :598 [DENY] reconciled to name this scan.
#   AC3 — threshold behavior on fixture digests: below-K, at-K, distinct-
#         issue dedup, window bound, dual-class-source, cross-axis-union,
#         dedup×window interaction, null-token skip, JSON field carriage,
#         --format=backlog conformance + injectable fixed scan-date,
#         --format=json byte-determinism.
#   AC4 — script writes-nothing (no-mutation guard, isolated temp copy) +
#         doc-assertion for the commit-batching rule (scratch/clean-tree/
#         dev-branch/no-direct-commit-to-main).
#   AC5 — docs/maintained-docs.md Improvement-Backlog trigger row updated.
#   AC6 — Decision-4 [DENY] boundary (no criteria auto-mod, candidate/human
#         promotion boundary).
#   AC7 — relationship to the per-issue loop-check documented (supplement,
#         not replace; bidirectional cross-reference).
#
# RED expectation (pre-implementation, this commit): AC1 (doc + boundedness),
# AC2 (doc + script-source), AC3 (script behavioral — the load-bearing test,
# no script exists), AC4-doc (batching rule not written), AC5, AC6, AC7 all
# FAIL. AC4's no-mutation half is a GUARD, vacuously green pre-impl (no
# script exists to mutate anything) — same guard-vs-RED split as #953's
# AC4/AC6 and #949's manifest-regen guard.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GUIDE_MD="$PROJECT_ROOT/docs/autoflow-guide.md"
ANALYSIS_MD="$PROJECT_ROOT/docs/phases/analysis.md"
MAINTAINED_MD="$PROJECT_ROOT/docs/maintained-docs.md"
DESIGN_RATIONALE_MD="$PROJECT_ROOT/docs/design-rationale.md"
BACKLOG_MD="$PROJECT_ROOT/docs/improvement-backlog.md"
SCAN_SCRIPT="$PROJECT_ROOT/scripts/preflight/scan-cross-issue-recurrence.sh"
SCHEMA_FIXTURE="$PROJECT_ROOT/tests/fixtures/cycle-digest-schema.json"

FX_BELOW_K="$PROJECT_ROOT/tests/fixtures/cycle-digest-954-below-k.jsonl"
FX_AT_K="$PROJECT_ROOT/tests/fixtures/cycle-digest-954-at-k.jsonl"
FX_DEDUP="$PROJECT_ROOT/tests/fixtures/cycle-digest-954-dedup.jsonl"
FX_WINDOW="$PROJECT_ROOT/tests/fixtures/cycle-digest-954-out-of-window.jsonl"
FX_DUAL_AXIS="$PROJECT_ROOT/tests/fixtures/cycle-digest-954-dual-axis.jsonl"
FX_CROSS_AXIS="$PROJECT_ROOT/tests/fixtures/cycle-digest-954-cross-axis.jsonl"
FX_DEDUP_WINDOW="$PROJECT_ROOT/tests/fixtures/cycle-digest-954-dedup-window.jsonl"

M_WINDOW=20
K_THRESHOLD=3

PASS=0; FAIL=0; TESTS=0

# ---------------------------------------------------------------------------
# Helpers (assert_* pattern per tests/test-issue-953-cycle-digest.sh)
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

skip_n() {
  local n="$1" label="$2"
  echo "  SKIP: $label"
  TESTS=$((TESTS + n))
}

# ---------------------------------------------------------------------------
# Section extractors (mirrors tests/test-issue-949-manifest-regen-doc.sh /
# tests/test-issue-953-cycle-digest.sh)
# ---------------------------------------------------------------------------

extract_section() {
  local heading_pattern="$1" file="$2"
  awk -v p="$heading_pattern" '
    $0 ~ p { f=1; next }
    f && /^## / { f=0 }
    f { print }
  ' "$file"
}

PREFLIGHT_BODY="$([ -f "$GUIDE_MD" ] && extract_section '^## PREFLIGHT' "$GUIDE_MD" || true)"
PREFLIGHT_JOINED="$(printf '%s' "$PREFLIGHT_BODY" | tr '\n' ' ')"
export PREFLIGHT_JOINED

# The :598 [DENY] clause sits inside HANDOFF, step 6.7 (per feature design F1
# and #953's own emission text) — extract HANDOFF too so AC2's reconciliation
# check has its own scoped body (not the whole file).
HANDOFF_BODY="$([ -f "$GUIDE_MD" ] && extract_section '^## HANDOFF' "$GUIDE_MD" || true)"
HANDOFF_JOINED="$(printf '%s' "$HANDOFF_BODY" | tr '\n' ' ')"
export HANDOFF_JOINED

echo "=== AC1 (RED discriminator) — PREFLIGHT step 1.5 wording ==="

assert_true "AC1-a: PREFLIGHT section names a cross-issue recurrence scan step (grep 'cross-issue' + 'recurrence')" \
  "printf '%s' \"\$PREFLIGHT_JOINED\" | grep -qiF 'cross-issue' && printf '%s' \"\$PREFLIGHT_JOINED\" | grep -qiF 'recurrence'"
assert_true "AC1-b: PREFLIGHT section places the step after prior-cycle resolution / before the Git Clean Check (step 1.5 token or explicit ordering language)" \
  "printf '%s' \"\$PREFLIGHT_JOINED\" | grep -qE '1\\.5|step 1\\.5' \
   || { printf '%s' \"\$PREFLIGHT_JOINED\" | grep -qiE 'after (step 1|prior-cycle resolution)' && printf '%s' \"\$PREFLIGHT_JOINED\" | grep -qiE 'before (step 2|.{0,20}clean.tree|git status)'; }"
assert_true "AC1-c: PREFLIGHT section declares an explicit model:\"sonnet\" spawn (Spawn Model [MUST])" \
  "printf '%s' \"\$PREFLIGHT_JOINED\" | grep -qF 'model' && printf '%s' \"\$PREFLIGHT_JOINED\" | grep -qF 'sonnet'"
assert_true "AC1-d: PREFLIGHT section names the autoflow-analyzer subagent_type (declared-role gate compliance)" \
  "printf '%s' \"\$PREFLIGHT_JOINED\" | grep -qF 'autoflow-analyzer'"
assert_true "AC1-e: PREFLIGHT section states the scan is bounded / single-shot / no loop (explicit termination phrasing)" \
  "printf '%s' \"\$PREFLIGHT_JOINED\" | grep -qiE 'single.shot' && printf '%s' \"\$PREFLIGHT_JOINED\" | grep -qiE 'no (retry|loop|iteration)'"
assert_true "AC1-f: PREFLIGHT section (or the script interface it documents) names the recent-window parameter as a literal number (M=20)" \
  "printf '%s' \"\$PREFLIGHT_JOINED\" | grep -qE 'M ?= ?20|window.{0,10}20|last 20'"
assert_true "AC1-g: PREFLIGHT section (or the script interface it documents) names the distinct-issue threshold as a literal number (K=3)" \
  "printf '%s' \"\$PREFLIGHT_JOINED\" | grep -qE 'K ?= ?3|threshold.{0,10}3|3 distinct'"

echo ""
echo "=== AC1 — script boundedness (guard; skipped if script absent) ==="

if [ -f "$SCAN_SCRIPT" ]; then
  assert_true "AC1-bounded: scan script reads at most the last M records once (tail -n) — no unbounded loop over cycles" \
    "grep -qE 'tail -n' '$SCAN_SCRIPT'"
  assert_false "AC1-no-infinite-loop: scan script contains no unbounded 'while true' / 'until true' construct" \
    "grep -qE 'while +true|until +true|while +:' '$SCAN_SCRIPT'"
else
  skip_n 2 "AC1-bounded/AC1-no-infinite-loop (script absent pre-impl)"
fi

# F6 (VERIFY step-3 coverage addition): the analyzer agent description names
# the scan variant, and the plugin package copy stays byte-identical
# (engine-parity rule, #955 plugin byte-copy precedent; #953's AC1-f analogue).
ANALYZER_MD="$PROJECT_ROOT/.claude/agents/autoflow-analyzer.md"
ANALYZER_PLUGIN_MD="$PROJECT_ROOT/plugin/autoflow/agents/autoflow-analyzer.md"
assert_true "AC1-h (F6): .claude/agents/autoflow-analyzer.md description names the cross-issue recurrence scan variant" \
  "grep -qF 'scan-cross-issue-recurrence' '$ANALYZER_MD'"
assert_true "AC1-i (F6): plugin/autoflow/agents/autoflow-analyzer.md is byte-identical to the .claude/agents copy (plugin parity)" \
  "cmp -s '$ANALYZER_MD' '$ANALYZER_PLUGIN_MD'"

echo ""
echo "=== AC2 (RED discriminator) — durable source = docs/cycle-digest.jsonl only, no .autoflow/ dependency ==="

assert_true "AC2-a: PREFLIGHT section names docs/cycle-digest.jsonl as the scan's corpus" \
  "printf '%s' \"\$PREFLIGHT_JOINED\" | grep -qF 'docs/cycle-digest.jsonl'"
assert_true "AC2-b: PREFLIGHT section carries an explicit negative clause that .autoflow/ is NOT the scan's corpus" \
  "printf '%s' \"\$PREFLIGHT_JOINED\" | grep -qiE 'not.{0,20}\\.autoflow|\\.autoflow.{0,40}(cannot|not).{0,20}corpus|gitignored scratch.{0,20}cannot be the corpus'"
assert_true "AC2-c (:598 reconciliation): HANDOFF's cycle-digest [DENY] clause names THIS PREFLIGHT scan as the (now-implemented) sanctioned reader, not a 'future' scan" \
  "printf '%s' \"\$HANDOFF_JOINED\" | grep -qiE 'cross-issue (recurrence )?scan' && ! printf '%s' \"\$HANDOFF_JOINED\" | grep -qiF 'a future cross-issue factual-tally scan'"

if [ -f "$SCAN_SCRIPT" ]; then
  assert_true "AC2-d: scan script's only corpus read names docs/cycle-digest.jsonl" \
    "grep -qF 'cycle-digest.jsonl' '$SCAN_SCRIPT'"
  assert_false "AC2-e: scan script does not find/glob .autoflow/*.json as a data source" \
    "grep -qE '\\.autoflow/.*\\.json|find .*\\.autoflow' '$SCAN_SCRIPT'"
  assert_false "AC7-scan-unaffected (issue #979): scan script carries no dependency on codex_max_severity/review_max_severity (verification design §1 AC-7 — the field the digest rename touches is out of the scan's read scope)" \
    "grep -qE 'codex_max_severity|review_max_severity' '$SCAN_SCRIPT'"

  # Contrast control: absent-digest input -> empty result, non-crash (no
  # silent fallback to .autoflow/).
  ABSENT_OUT="$(bash "$SCAN_SCRIPT" "$PROJECT_ROOT/tests/fixtures/does-not-exist-954.jsonl" "$M_WINDOW" "$K_THRESHOLD" --format=json 2>/dev/null)"
  ABSENT_EXIT=$?
  assert_true "AC2-f: absent digest input exits 0 with an empty JSON array (tolerant-default, no crash, no fallback)" \
    "[ '$ABSENT_EXIT' -eq 0 ] && printf '%s' '$ABSENT_OUT' | jq -e '. == []' >/dev/null 2>&1"
else
  skip_n 3 "AC2-d/AC2-e/AC2-f (script absent pre-impl)"
fi

echo ""
echo "=== AC3 (RED discriminator, load-bearing) — threshold behavior on fixture digests ==="

if [ -x "$SCAN_SCRIPT" ]; then

  BELOW_K_OUT="$(bash "$SCAN_SCRIPT" "$FX_BELOW_K" "$M_WINDOW" "$K_THRESHOLD" --format=json 2>/dev/null)"
  assert_true "AC3-below-k: a class in only 2 distinct issues (K-1) emits NO candidate finding" \
    "printf '%s' '$BELOW_K_OUT' | jq -e '. == []' >/dev/null 2>&1"

  AT_K_OUT="$(bash "$SCAN_SCRIPT" "$FX_AT_K" "$M_WINDOW" "$K_THRESHOLD" --format=json 2>/dev/null)"
  export AT_K_OUT
  assert_true "AC3-at-k: a class in exactly 3 distinct issues emits exactly ONE candidate finding" \
    "printf '%s' \"\$AT_K_OUT\" | jq -e '(type == \"array\") and (length == 1)' >/dev/null 2>&1"
  assert_true "AC3-at-k-class: the emitted finding's class is 'mock-boundary-drift'" \
    "printf '%s' \"\$AT_K_OUT\" | jq -e '.[0].class == \"mock-boundary-drift\"' >/dev/null 2>&1"

  DEDUP_OUT="$(bash "$SCAN_SCRIPT" "$FX_DEDUP" "$M_WINDOW" "$K_THRESHOLD" --format=json 2>/dev/null)"
  assert_true "AC3-dedup: same class in 4 records but only 2 DISTINCT issues emits NO finding (counted by distinct issue, not by record)" \
    "printf '%s' '$DEDUP_OUT' | jq -e '. == []' >/dev/null 2>&1"

  WINDOW_OUT="$(bash "$SCAN_SCRIPT" "$FX_WINDOW" "$M_WINDOW" "$K_THRESHOLD" --format=json 2>/dev/null)"
  assert_true "AC3-window: a class reaching K only via records older than the last M is NOT counted (window honored)" \
    "printf '%s' '$WINDOW_OUT' | jq -e '. == []' >/dev/null 2>&1"

  DEDUP_WINDOW_OUT="$(bash "$SCAN_SCRIPT" "$FX_DEDUP_WINDOW" "$M_WINDOW" "$K_THRESHOLD" --format=json 2>/dev/null)"
  export DEDUP_WINDOW_OUT
  assert_true "AC3-dedup-window: dedup×window composition — one issue's in-window record still credits it, alongside 2 other in-window issues -> BREACH at K=3" \
    "printf '%s' \"\$DEDUP_WINDOW_OUT\" | jq -e '(type==\"array\") and (length==1) and (.[0].distinct_issues | sort) == [\"#960\",\"#961\",\"#962\"]' >/dev/null 2>&1"

  CROSS_AXIS_OUT="$(bash "$SCAN_SCRIPT" "$FX_CROSS_AXIS" "$M_WINDOW" "$K_THRESHOLD" --format=json 2>/dev/null)"
  export CROSS_AXIS_OUT
  assert_true "AC3-cross-axis-union: a class seen via loop_check_class in one issue and escaped_defects in two others breaches at K=3 (cross-axis counting)" \
    "printf '%s' \"\$CROSS_AXIS_OUT\" | jq -e '(type==\"array\") and (length==1) and (.[0].distinct_issues | sort) == [\"#941\",\"#949\",\"#953\"]' >/dev/null 2>&1"
  assert_true "AC3-normalization: the loop_check witness's '  Correctness  ' token normalizes (trim+lowercase) to the same class as the escaped_defect witnesses' 'correctness'" \
    "printf '%s' \"\$CROSS_AXIS_OUT\" | jq -e '.[0].class == \"correctness\"' >/dev/null 2>&1"
  assert_true "AC3-witness-axis-provenance: witnesses[] carry BOTH axis values (loop_check and escaped_defect), proving dual-source coverage" \
    "printf '%s' \"\$CROSS_AXIS_OUT\" | jq -e '([.[0].witnesses[].axis] | unique | sort) == [\"escaped_defect\",\"loop_check\"]' >/dev/null 2>&1"

  DUAL_AXIS_OUT="$(bash "$SCAN_SCRIPT" "$FX_DUAL_AXIS" "$M_WINDOW" "$K_THRESHOLD" --format=json 2>/dev/null)"
  assert_true "AC3-dual-axis-below-threshold: the same normalized class split across loop_check_class (#930) and escaped_defects (#931) is still only 2 distinct issues -> no finding" \
    "printf '%s' '$DUAL_AXIS_OUT' | jq -e '. == []' >/dev/null 2>&1"

  # Field carriage (AC3 step 5): the breach object carries every field the
  # candidate finding must be rendered from.
  assert_true "AC3-field-carriage: breach object carries class/distinct_issues/count/window/threshold/witnesses[] with axis+surface+codex_anchor" \
    "printf '%s' \"\$CROSS_AXIS_OUT\" | jq -e '
      .[0] as \$b
      | (\$b | has(\"class\")) and (\$b | has(\"distinct_issues\")) and (\$b | has(\"count\"))
        and (\$b | has(\"window\")) and (\$b | has(\"threshold\"))
        and (\$b.witnesses | type == \"array\")
        and (\$b.witnesses | map(has(\"axis\") and has(\"surface\") and has(\"codex_anchor\")) | all)
    ' >/dev/null 2>&1"
  assert_true "AC3-count-window-threshold: breach object's count/window/threshold echo the invocation parameters (3/20/3)" \
    "printf '%s' \"\$CROSS_AXIS_OUT\" | jq -e '.[0].count == 3 and .[0].window == 20 and .[0].threshold == 3' >/dev/null 2>&1"

  # null-token skip: a record whose loop_check_class is null and whose
  # escaped_defects is empty contributes no class token and does not crash
  # the tally (exercised implicitly by every fixture's filler lines above;
  # assert directly here on a purpose-built minimal case).
  NULL_TOKEN_LINE='{"issue":"#999","terminal_cycle":1,"date":"2026-06-01","mode":"new-issue","gates":{"gate_hypothesis_structure":{"pass":true,"avg":8,"items":{},"below7":[]},"gate_hypothesis_cause":{"verdict":"skipped (feat issue)"},"gate_plan":{"pass":true,"avg":8,"items":{},"below7":[]},"audit":{"pass":true,"avg":8,"items":{},"below7":[]},"gate_quality":{"pass":true,"avg":8,"items":{},"below7":[]}},"regressions":{"gate_plan":0,"verify":0,"audit":0,"gate_quality":0,"review_autofix_cycles":0},"architect":{"rounds":0,"escalate":false},"loop_check_class":null,"review_max_severity":"None","escaped_defects":[]}'
  NULL_TOKEN_TMP="$(mktemp)"
  printf '%s\n' "$NULL_TOKEN_LINE" > "$NULL_TOKEN_TMP"
  NULL_TOKEN_OUT="$(bash "$SCAN_SCRIPT" "$NULL_TOKEN_TMP" "$M_WINDOW" "$K_THRESHOLD" --format=json 2>/dev/null)"
  NULL_TOKEN_EXIT=$?
  assert_true "AC3-null-token-skip: a record with loop_check_class=null and escaped_defects=[] does not crash and yields no finding" \
    "[ '$NULL_TOKEN_EXIT' -eq 0 ] && printf '%s' '$NULL_TOKEN_OUT' | jq -e '. == []' >/dev/null 2>&1"
  rm -f "$NULL_TOKEN_TMP"

  # --format=json byte-determinism: same corpus -> byte-identical output.
  DET_RUN1="$(bash "$SCAN_SCRIPT" "$FX_CROSS_AXIS" "$M_WINDOW" "$K_THRESHOLD" --format=json 2>/dev/null)"
  DET_RUN2="$(bash "$SCAN_SCRIPT" "$FX_CROSS_AXIS" "$M_WINDOW" "$K_THRESHOLD" --format=json 2>/dev/null)"
  assert_true "AC3-json-determinism: two invocations on the same corpus produce byte-identical --format=json output" \
    "[ \"\$DET_RUN1\" = \"\$DET_RUN2\" ] && [ -n \"\$DET_RUN1\" ]"

  # --format=backlog conformance (AC3 step 6): the §7 candidate block, with
  # an injectable fixed scan-date for byte-level assertion (non-blocking
  # GATE:PLAN recommendation, feature §5). Convention assumed by this test:
  # env var XISSUE_SCAN_DATE overrides the embedded scan date.
  BACKLOG_OUT="$(XISSUE_SCAN_DATE=2026-07-09 bash "$SCAN_SCRIPT" "$FX_CROSS_AXIS" "$M_WINDOW" "$K_THRESHOLD" --format=backlog 2>/dev/null)"
  export BACKLOG_OUT
  assert_true "AC3-backlog-heading: --format=backlog emits a '### \`xissue-scan-correctness-...\`' heading for the breached class" \
    "printf '%s' \"\$BACKLOG_OUT\" | grep -qE '^### \`xissue-scan-correctness-'"
  assert_true "AC3-backlog-sections: --format=backlog output carries all required subsections (분류/문제/영향/권고/검증/근거 anchor/재발 상태)" \
    "printf '%s' \"\$BACKLOG_OUT\" | grep -qF '**분류**' \
     && printf '%s' \"\$BACKLOG_OUT\" | grep -qF '**문제**' \
     && printf '%s' \"\$BACKLOG_OUT\" | grep -qF '**영향**' \
     && printf '%s' \"\$BACKLOG_OUT\" | grep -qF '**권고**' \
     && printf '%s' \"\$BACKLOG_OUT\" | grep -qF '**검증**' \
     && printf '%s' \"\$BACKLOG_OUT\" | grep -qiF '근거 anchor' \
     && printf '%s' \"\$BACKLOG_OUT\" | grep -qF '**재발 상태**'"
  assert_true "AC3-backlog-witnesses: --format=backlog output names all 3 witness issues (#941, #949, #953)" \
    "printf '%s' \"\$BACKLOG_OUT\" | grep -qF '#941' && printf '%s' \"\$BACKLOG_OUT\" | grep -qF '#949' && printf '%s' \"\$BACKLOG_OUT\" | grep -qF '#953'"
  assert_true "AC3-backlog-injected-date: the injectable fixed scan-date (XISSUE_SCAN_DATE=2026-07-09) appears byte-exact in the rendered block" \
    "printf '%s' \"\$BACKLOG_OUT\" | grep -qF '2026-07-09'"

  BACKLOG_BELOW_OUT="$(bash "$SCAN_SCRIPT" "$FX_BELOW_K" "$M_WINDOW" "$K_THRESHOLD" --format=backlog 2>/dev/null)"
  BACKLOG_BELOW_EXIT=$?
  assert_true "AC3-backlog-empty: --format=backlog on a below-threshold fixture prints NOTHING (empty stdout, exit 0)" \
    "[ -z \"\$BACKLOG_BELOW_OUT\" ] && [ '$BACKLOG_BELOW_EXIT' -eq 0 ]"

  # VERIFY step-3 coverage additions (impl behaviors present at b26cda9 that
  # the RED suite did not yet pin):
  # (a) malformed-invocation contract (feature §5 behavior 7): unknown
  #     --format and non-numeric M exit non-zero — breach/no-breach both
  #     exit 0, ONLY a malformed invocation is an error.
  bash "$SCAN_SCRIPT" "$FX_AT_K" "$M_WINDOW" "$K_THRESHOLD" --format=nope >/dev/null 2>&1
  MALFORMED_FMT_EXIT=$?
  bash "$SCAN_SCRIPT" "$FX_AT_K" "notanumber" "$K_THRESHOLD" --format=json >/dev/null 2>&1
  MALFORMED_M_EXIT=$?
  assert_true "AC3-malformed-format: unknown --format=… exits non-zero (malformed invocation, feature §5 step 7)" \
    "[ '$MALFORMED_FMT_EXIT' -ne 0 ]"
  assert_true "AC3-malformed-M: non-numeric M exits non-zero (malformed invocation, feature §5 step 7)" \
    "[ '$MALFORMED_M_EXIT' -ne 0 ]"

  # (b) markdown-structure injection sanitization: digest-sourced tokens
  #     (class/surface/anchor) are stripped of backticks in the rendered
  #     block, so a hostile token cannot break out of its code span.
  SAN_TMP="$(mktemp)"
  for iss in '#980' '#981' '#982'; do
    jq -nc --arg issue "$iss" '{
      issue: $issue, terminal_cycle: 1, date: "2026-06-01", mode: "new-issue",
      gates: {
        gate_hypothesis_structure: {pass:true, avg:8, items:{}, below7:[]},
        gate_hypothesis_cause: {verdict:"skipped (feat issue)"},
        gate_plan: {pass:true, avg:8, items:{}, below7:[]},
        audit: {pass:true, avg:8, items:{}, below7:[]},
        gate_quality: {pass:true, avg:8, items:{}, below7:[]}
      },
      regressions: {gate_plan:0, verify:0, audit:0, gate_quality:0, review_autofix_cycles:0},
      architect: {rounds:0, escalate:false},
      loop_check_class: "Bad`Tick",
      review_max_severity: "None",
      escaped_defects: []
    }' >> "$SAN_TMP"
  done
  SAN_OUT="$(XISSUE_SCAN_DATE=2026-07-09 bash "$SCAN_SCRIPT" "$SAN_TMP" "$M_WINDOW" "$K_THRESHOLD" --format=backlog 2>/dev/null)"
  export SAN_OUT
  assert_true "AC3-backlog-sanitize: a backtick-carrying class token is rendered with the backtick stripped (heading id 'xissue-scan-badtick-')" \
    "grep -qF 'xissue-scan-badtick-' <<<\"\$SAN_OUT\""
  assert_false "AC3-backlog-sanitize-negative: the raw backtick-embedded token ('bad\`tick') never appears in the rendered block" \
    "grep -qF 'bad\`tick' <<<\"\$SAN_OUT\""
  rm -f "$SAN_TMP"

  # (c) AUDIT finding (input_validation 5/10) — the digest-sourced `.issue`
  #     field is ALSO interpolated into the backlog render (the summary
  #     $issues join and the per-witness bullets) and must pass the same
  #     `san` sanitizer as class/surface/codex_anchor: a hostile issue value
  #     with an embedded newline otherwise breaks out of its line and renders
  #     an injected markdown heading inside the candidate block.
  SAN_ISSUE_TMP="$(mktemp)"
  for iss in '#990' '#991' $'#992\n## INJECTED HEADING `x`'; do
    jq -nc --arg issue "$iss" '{
      issue: $issue, terminal_cycle: 1, date: "2026-06-01", mode: "new-issue",
      gates: {
        gate_hypothesis_structure: {pass:true, avg:8, items:{}, below7:[]},
        gate_hypothesis_cause: {verdict:"skipped (feat issue)"},
        gate_plan: {pass:true, avg:8, items:{}, below7:[]},
        audit: {pass:true, avg:8, items:{}, below7:[]},
        gate_quality: {pass:true, avg:8, items:{}, below7:[]}
      },
      regressions: {gate_plan:0, verify:0, audit:0, gate_quality:0, review_autofix_cycles:0},
      architect: {rounds:0, escalate:false},
      loop_check_class: "issue-inject-class",
      review_max_severity: "None",
      escaped_defects: []
    }' >> "$SAN_ISSUE_TMP"
  done
  SAN_ISSUE_OUT="$(XISSUE_SCAN_DATE=2026-07-09 bash "$SCAN_SCRIPT" "$SAN_ISSUE_TMP" "$M_WINDOW" "$K_THRESHOLD" --format=backlog 2>/dev/null)"
  export SAN_ISSUE_OUT
  assert_false "AC3-backlog-sanitize-issue: a hostile .issue value with an embedded newline never renders an injected markdown heading (no output line starts '## INJECTED')" \
    "grep -qE '^## INJECTED' <<<\"\$SAN_ISSUE_OUT\""
  assert_false "AC3-backlog-sanitize-issue-negative: no backtick from the hostile .issue payload survives into the rendered block (payload code-span '\`x\`' absent)" \
    "grep -qF '\`x\`' <<<\"\$SAN_ISSUE_OUT\""
  rm -f "$SAN_ISSUE_TMP"

else
  skip_n 21 "AC3 (script absent or not executable pre-impl)"
fi

echo ""
echo "=== AC4 (RED discriminator/guard) — script writes-nothing + commit-batching doc rule ==="

# Guard (vacuously green pre-impl per verification design AC4): isolated
# temp copy limited to what the script needs (not the whole 2GB working
# tree — the script is a self-contained bash file reading only its own
# path + the digest path, so a full-tree tar copy is unnecessary weight),
# invoke the scan, then assert git status is byte-clean (no tracked-file
# mutation, no untracked residue).
AC4_TMP="$(mktemp -d)"
mkdir -p "$AC4_TMP/scripts/preflight" "$AC4_TMP/docs"
[ -f "$SCAN_SCRIPT" ] && cp "$SCAN_SCRIPT" "$AC4_TMP/scripts/preflight/"
cp "$FX_AT_K" "$AC4_TMP/docs/cycle-digest.jsonl"
(cd "$AC4_TMP" && git init -q && git add -A && git -c user.email=t@t.co -c user.name=t commit -q -m fixture)

if [ -f "$AC4_TMP/scripts/preflight/scan-cross-issue-recurrence.sh" ]; then
  ( cd "$AC4_TMP" && bash scripts/preflight/scan-cross-issue-recurrence.sh docs/cycle-digest.jsonl "$M_WINDOW" "$K_THRESHOLD" --format=backlog >/dev/null 2>&1 )
fi
AC4_PORCELAIN="$(cd "$AC4_TMP" && git status --porcelain 2>/dev/null)"
export AC4_PORCELAIN
assert_true "AC4-no-mutation (guard): invoking the scan in an isolated temp copy leaves 'git status --porcelain' byte-clean (no tracked or untracked mutation)" \
  "[ -z \"\$AC4_PORCELAIN\" ]"
rm -rf "$AC4_TMP"

assert_true "AC4-doc-batching: PREFLIGHT/HANDOFF prose states the real backlog append is a SEPARATE dev-branch infra commit outside PREFLIGHT's clean-tree check window" \
  "{ printf '%s' \"\$PREFLIGHT_JOINED\"; printf '%s' \"\$HANDOFF_JOINED\"; } | grep -qiF 'scratch' \
   && { printf '%s' \"\$PREFLIGHT_JOINED\"; printf '%s' \"\$HANDOFF_JOINED\"; } | grep -qiF 'dev branch' \
   && { printf '%s' \"\$PREFLIGHT_JOINED\"; printf '%s' \"\$HANDOFF_JOINED\"; } | grep -qiE 'clean.tree'"
assert_true "AC4-doc-no-direct-write: the batching prose states the append never happens as a direct write during PREFLIGHT's step / clean-tree window" \
  "{ printf '%s' \"\$PREFLIGHT_JOINED\"; printf '%s' \"\$HANDOFF_JOINED\"; } | grep -qiE 'outside (preflight|the clean.tree)|not (during|inside) preflight'"
assert_true "AC4-doc-no-main-commit: the batching prose confirms the append never commits to main (no-direct-commit-to-main invariant preserved)" \
  "{ printf '%s' \"\$PREFLIGHT_JOINED\"; printf '%s' \"\$HANDOFF_JOINED\"; } | grep -qiE 'never (commits?|on) main|not (on|to) main'"

echo ""
echo "=== AC5 (RED discriminator) — docs/maintained-docs.md Improvement Backlog trigger updated ==="

if [ -f "$MAINTAINED_MD" ]; then
  BACKLOG_ROW="$(grep -F 'Improvement Backlog' "$MAINTAINED_MD" | head -n1)"
  export BACKLOG_ROW
  assert_true "AC5: the Improvement Backlog registry row's Update-When column now also names the cycle-driven / PREFLIGHT cross-issue scan as an intake trigger" \
    "printf '%s' \"\$BACKLOG_ROW\" | grep -qiE 'cycle.driven|preflight scan|cross.issue recurrence'"
else
  assert_true "AC5-file-exists: docs/maintained-docs.md exists" "false"
fi

echo ""
echo "=== AC6 (RED discriminator) — Decision 4 alignment: criteria auto-mod [DENY], candidate/human boundary ==="

# SIGPIPE-safe (Testing Standards item 6, #964): the combined prose is
# ~120KB — a `printf | grep -q` pipe under pipefail dies rc-141 when grep's
# early exit SIGPIPEs the still-writing printf. Use here-strings (no pipe).
SCAN_STEP_AND_BACKLOG="$(printf '%s' "$PREFLIGHT_JOINED"; [ -f "$BACKLOG_MD" ] && cat "$BACKLOG_MD")"
export SCAN_STEP_AND_BACKLOG
assert_true "AC6-deny: the PREFLIGHT scan step (and/or backlog-append prose) carries an explicit [DENY] against auto-modifying evaluation criteria/rubrics" \
  "grep -qF '[DENY]' <<<\"\$SCAN_STEP_AND_BACKLOG\" && grep -qiE 'criteria|rubric' <<<\"\$SCAN_STEP_AND_BACKLOG\""
assert_true "AC6-candidate-human: the same prose states the output is a CANDIDATE finding whose promotion to an issue stays human-external" \
  "grep -qiF 'candidate' <<<\"\$SCAN_STEP_AND_BACKLOG\" && grep -qiE 'human' <<<\"\$SCAN_STEP_AND_BACKLOG\""
assert_true "AC6-decision4-xref: the prose cross-references Decision 4 / design-rationale.md and that anchor resolves (Decision 4 exists there)" \
  "grep -qiE 'decision 4|design-rationale' <<<\"\$SCAN_STEP_AND_BACKLOG\" && grep -qF 'Decision 4' '$DESIGN_RATIONALE_MD'"

echo ""
echo "=== AC7 (RED discriminator) — relationship to per-issue loop-check documented ==="

ANALYSIS_LOOPCHECK="$([ -f "$ANALYSIS_MD" ] && extract_section '^Review-response loop check' "$ANALYSIS_MD" || true)"
ANALYSIS_LOOPCHECK_JOINED="$(printf '%s' "$ANALYSIS_LOOPCHECK" | tr '\n' ' ')"
COMBINED_AC7="$(printf '%s ' "$ANALYSIS_LOOPCHECK_JOINED"; printf '%s' "$PREFLIGHT_JOINED")"
export COMBINED_AC7
assert_true "AC7-supplement: the loop-check doc and/or the PREFLIGHT scan step state the cross-issue scan SUPPLEMENTS, does not replace, the per-issue loop-check" \
  "printf '%s' \"\$COMBINED_AC7\" | grep -qiE 'supplement' && printf '%s' \"\$COMBINED_AC7\" | grep -qiE 'not replace|does not replace'"
assert_true "AC7-scope-distinction: the relationship prose spells out the scope distinction (single-issue/consecutive vs. cross-issue/cumulative)" \
  "printf '%s' \"\$COMBINED_AC7\" | grep -qiE 'per.issue' && printf '%s' \"\$COMBINED_AC7\" | grep -qiE 'cross.issue'"
assert_true "AC7-bidirectional: BOTH sides carry the cross-reference (loop-check doc mentions the cross-issue scan AND the PREFLIGHT step mentions the loop-check) — no dangling one-sided reference" \
  "printf '%s' \"\$ANALYSIS_LOOPCHECK_JOINED\" | grep -qiE 'cross.issue' && printf '%s' \"\$PREFLIGHT_JOINED\" | grep -qiE 'loop.check'"

# F7 doc-sync (VERIFY step-3 coverage addition): design-rationale's Known
# Limitations no longer claims the scan is only "under internal discussion" —
# it names the shipped script while keeping judgment/promotion human-external.
assert_true "AC7-dr-sync (F7): design-rationale Known Limitations names the shipped scan script (no stale 'future scan only' claim)" \
  "grep -qF 'scan-cross-issue-recurrence.sh' '$DESIGN_RATIONALE_MD'"

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
