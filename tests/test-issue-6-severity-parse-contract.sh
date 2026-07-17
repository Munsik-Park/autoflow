#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: emit-cycle-digest.sh severity parsing contract — Issue #6
# =============================================================================
# Tier-1 scripted assertion suite per verification design
# (.autoflow/issue-6-verification-design.md) / feature design
# (.autoflow/issue-6-feature-design.md). Docs + script change (no jest, no
# npm) — reuses the isolated-temp-copy fixture pattern already established at
# tests/test-issue-953-cycle-digest.sh (F7/F7b/RR2 blocks, RR2-AC1 lightweight
# scripts/handoff-only copy variant).
#
# Placement (verification design §1, ratified feature design §4.4): a
# DEDICATED file, not an in-place extension of test-issue-953-cycle-digest.sh
# — per-issue test isolation is the established convention and #953 already
# carries seven AC blocks. This suite re-runs #953's F7/F7b/RR2 arms
# unchanged as an explicit regression guard (AC6).
#
# Scope (verification design §2, feature design §6 — shared AC namespace):
#   AC1 — `=`-tolerant grammar widen (Approach 2): equals-separator input is
#         accepted and canonicalized; sibling separator forms asserted too.
#   AC2 — fail-loud (Approach 3, core): a *present* findings file whose
#         max_severity does not resolve to a valid enum -> non-zero exit,
#         diagnosable stderr, no digest append. Three-fixture boundary set:
#         (a) out-of-enum value, (b) enum-superset DCR-4 witness, (c) key
#         entirely absent (shape 1, boundary (B)).
#   AC3 — regression: legitimate absence (no findings file / empty arg) still
#         yields review_max_severity == "None", exit 0, append occurs.
#   AC4 — fail-loud discrimination witness: a present file with a VALID
#         max_severity (incl. the highest over-block-risk clean-None-present
#         case) still emits normally — proves AC2 blocks only the
#         unparseable-present case.
#   AC5 — producer-contract pin (Approach 1, doc-assertion): HANDOFF step 6.5
#         pins both presence and notation of the max_severity line; step 6.7
#         discloses the new fail-loud behavior.
#   AC6 — no-regression: `bash tests/test-issue-953-cycle-digest.sh` still
#         reports 0 failures.
#
# RED expectation (pre-implementation, verification design §5): within AC1,
# only the `=`-separator arms are true RED discriminators — the bare-space
# and no-separator forms already match the as-is colon-optional grammar
# (`max_severity:?[[:space:]]*(enum)`) and are guard/regression-pass legs,
# the same "guard vs RED discriminator" split used by
# tests/test-issue-949-manifest-regen-doc.sh and test-issue-953's own header.
# AC2 is fully RED (fail-loud does not exist yet — every fixture exits 0 and
# appends a false record). AC3 and the AC4 guard fixtures PASS pre-impl
# (existing correct behavior, must stay green through GREEN). AC5 is fully
# RED (no normative notation/presence statement exists in
# docs/autoflow-guide.md yet). AC6 PASSES pre-impl (baseline #953 suite is
# green) and guards GREEN against regression.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

EMIT_SCRIPT="$PROJECT_ROOT/scripts/handoff/emit-cycle-digest.sh"
GUIDE_MD="$PROJECT_ROOT/docs/autoflow-guide.md"
DIGEST_953_SUITE="$PROJECT_ROOT/tests/test-issue-953-cycle-digest.sh"

PASS=0; FAIL=0; TESTS=0

# ---------------------------------------------------------------------------
# Helpers (assert_* pattern per tests/test-issue-953-cycle-digest.sh /
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

# Step extractor for the AC5 doc-assertion: HANDOFF numbered steps are NOT
# markdown headings (they are numbered-paragraph lines, e.g. "6.5. Review
# triage ..."), so this bounds a block from the start-step line up to (but
# excluding) the next numbered-step line, mirroring the bounded paragraph
# extractor already used in tests/test-issue-953-cycle-digest.sh.
extract_step() {
  local start_pat="$1" end_pat="$2" file="$3"
  awk -v s="$start_pat" -v e="$end_pat" '
    $0 ~ s { f = 1 }
    f && $0 ~ e && $0 !~ s { exit }
    f { print }
  ' "$file"
}

# ---------------------------------------------------------------------------
# run_fixture — isolated-temp-copy invocation of emit-cycle-digest.sh
# (lightweight scripts/handoff-only copy, mirroring
# tests/test-issue-953-cycle-digest.sh's RR2-AC1 pattern). Seeds a 1-line
# docs/cycle-digest.jsonl so append vs. no-append is observable via line
# count. Globals set on return: RUN_EXIT, RUN_STDERR, RUN_LINE_COUNT,
# RUN_LINE2.
#
#   mode=none     -> findings arg is the empty string (legitimate absence)
#   mode=missing  -> findings arg is a path that does not exist
#   mode=content  -> $3 is written verbatim as the findings file body
# ---------------------------------------------------------------------------

SEED_LINE='{"issue":"#0","terminal_cycle":1,"date":"2026-01-01","mode":"new-issue","gates":{},"regressions":{},"architect":{"rounds":0,"escalate":false},"loop_check_class":null,"review_max_severity":"None","escaped_defects":[]}'

run_fixture() {
  local mode="$1" content="${2:-}"
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/scripts/handoff" "$tmp/.autoflow" "$tmp/docs"
  cp "$EMIT_SCRIPT" "$tmp/scripts/handoff/emit-cycle-digest.sh"
  chmod +x "$tmp/scripts/handoff/emit-cycle-digest.sh"
  cat > "$tmp/.autoflow/issue-0.json" <<'EOF'
{ "issue": "#0", "cycle": 1, "date": "2026-07-17", "mode": "new-issue", "phases": {} }
EOF
  : > "$tmp/.autoflow/ledger.md"
  printf '%s\n' "$SEED_LINE" > "$tmp/docs/cycle-digest.jsonl"

  local findings_arg=""
  case "$mode" in
    none)
      findings_arg=""
      ;;
    missing)
      findings_arg=".autoflow/issue-0-review-findings-does-not-exist.md"
      ;;
    content)
      printf '%s\n' "$content" > "$tmp/.autoflow/issue-0-review-findings.md"
      findings_arg=".autoflow/issue-0-review-findings.md"
      ;;
  esac

  ( cd "$tmp" && bash scripts/handoff/emit-cycle-digest.sh \
      .autoflow/issue-0.json .autoflow/ledger.md "$findings_arg" \
      >"$tmp/stdout.log" 2>"$tmp/stderr.log" )
  RUN_EXIT=$?
  RUN_STDERR="$(cat "$tmp/stderr.log" 2>/dev/null)"
  if [ -f "$tmp/docs/cycle-digest.jsonl" ]; then
    RUN_LINE_COUNT="$(wc -l < "$tmp/docs/cycle-digest.jsonl" | tr -d ' ')"
    RUN_LINE2="$(sed -n '2p' "$tmp/docs/cycle-digest.jsonl")"
  else
    RUN_LINE_COUNT="0"
    RUN_LINE2=""
  fi
  export RUN_EXIT RUN_STDERR RUN_LINE_COUNT RUN_LINE2
  rm -rf "$tmp"
}

if [ ! -x "$EMIT_SCRIPT" ]; then
  assert_true "PRECONDITION: scripts/handoff/emit-cycle-digest.sh exists and is executable" "false"
  echo ""
  echo "=============================="
  echo "Results: $PASS/$TESTS passed, $FAIL failed"
  echo "=============================="
  exit 1
fi

# =============================================================================
echo "=== AC1 (Approach 2) — '=' -tolerant separator grammar widen ==="
# =============================================================================

# --- RED discriminator: the equals separator (primary) -----------------------
run_fixture content 'max_severity = Low'
assert_true "AC1-eq-spaces (RED): 'max_severity = Low' exits 0" \
  "[ '$RUN_EXIT' -eq 0 ]"
assert_true "AC1-eq-spaces (RED): review_max_severity resolves to \"Low\", exit 0, append occurs" \
  "printf '%s' '$RUN_LINE2' | jq -e '.review_max_severity == \"Low\"' >/dev/null 2>&1"

run_fixture content 'max_severity=Low'
assert_true "AC1-eq-nospace (RED): 'max_severity=Low' (no spaces) exits 0" \
  "[ '$RUN_EXIT' -eq 0 ]"
assert_true "AC1-eq-nospace (RED): review_max_severity resolves to \"Low\"" \
  "printf '%s' '$RUN_LINE2' | jq -e '.review_max_severity == \"Low\"' >/dev/null 2>&1"

# --- Sibling accepted forms (guard — already accepted by the as-is
#     colon-optional grammar `max_severity:?[[:space:]]*(enum)`; PASS
#     pre-impl, must stay green through GREEN) ---------------------------------
run_fixture content 'max_severity Low'
assert_true "AC1-bare-space (guard, pre-impl PASS): 'max_severity Low' exits 0 and resolves to \"Low\"" \
  "[ '$RUN_EXIT' -eq 0 ] && printf '%s' '$RUN_LINE2' | jq -e '.review_max_severity == \"Low\"' >/dev/null 2>&1"

run_fixture content 'max_severityLow'
assert_true "AC1-no-separator (guard, pre-impl PASS, DCR-3): 'max_severityLow' exits 0 and resolves to \"Low\"" \
  "[ '$RUN_EXIT' -eq 0 ] && printf '%s' '$RUN_LINE2' | jq -e '.review_max_severity == \"Low\"' >/dev/null 2>&1"

run_fixture content 'max_severity: Medium'
assert_true "AC1-colon-regression (guard, pre-impl PASS): 'max_severity: Medium' exits 0 and resolves to \"Medium\"" \
  "[ '$RUN_EXIT' -eq 0 ] && printf '%s' '$RUN_LINE2' | jq -e '.review_max_severity == \"Medium\"' >/dev/null 2>&1"

# =============================================================================
echo ""
echo "=== AC2 (Approach 3, core, RED) — fail-loud on a present-but-unparseable findings file ==="
# =============================================================================

# (a) out-of-enum value, no enum substring at all.
run_fixture content 'max_severity: Moderate'
assert_true "AC2a-out-of-enum (RED): 'max_severity: Moderate' exits non-zero" \
  "[ '$RUN_EXIT' -ne 0 ]"
assert_true "AC2a-out-of-enum (RED): stderr names the offending token 'max_severity' (DCR-2)" \
  "printf '%s' '$RUN_STDERR' | grep -qF 'max_severity'"
assert_true "AC2a-out-of-enum (RED): docs/cycle-digest.jsonl line count unchanged (still 1 — no append)" \
  "[ '$RUN_LINE_COUNT' -eq 1 ]"

# (b) enum-superset boundary witnesses — DCR-4. Unanchored grammar prefix-
#     matches these into a false-clean record; this is the exact issue-#6
#     defect class.
run_fixture content 'max_severity: Nonexistent'
assert_true "AC2b-enum-superset-nonexistent (RED, DCR-4): 'max_severity: Nonexistent' exits non-zero (not a false-clean None)" \
  "[ '$RUN_EXIT' -ne 0 ]"
assert_true "AC2b-enum-superset-nonexistent (RED, DCR-4): stderr names 'max_severity'" \
  "printf '%s' '$RUN_STDERR' | grep -qF 'max_severity'"
assert_true "AC2b-enum-superset-nonexistent (RED, DCR-4): line count unchanged (still 1 — no append)" \
  "[ '$RUN_LINE_COUNT' -eq 1 ]"

run_fixture content 'max_severity: Lowest'
assert_true "AC2b-enum-superset-lowest (RED, DCR-4): 'max_severity: Lowest' exits non-zero (not a false prefix-match to Low)" \
  "[ '$RUN_EXIT' -ne 0 ]"
assert_true "AC2b-enum-superset-lowest (RED, DCR-4): line count unchanged (still 1 — no append)" \
  "[ '$RUN_LINE_COUNT' -eq 1 ]"

# (c) key entirely absent from a present findings file (shape 1, boundary B).
run_fixture content $'# Review findings (fixture — shape 1, key entirely absent)\nfindings: none\nlow_confidence_items: []'
assert_true "AC2c-key-absent (RED, boundary B): a present findings file with no max_severity line exits non-zero" \
  "[ '$RUN_EXIT' -ne 0 ]"
assert_true "AC2c-key-absent (RED, boundary B): stderr names 'max_severity'" \
  "printf '%s' '$RUN_STDERR' | grep -qF 'max_severity'"
assert_true "AC2c-key-absent (RED, boundary B): line count unchanged (still 1 — no append)" \
  "[ '$RUN_LINE_COUNT' -eq 1 ]"

# =============================================================================
echo ""
echo "=== AC3 (regression guard) — legitimate absence still yields None, exit 0, append ==="
# =============================================================================

run_fixture none
assert_true "AC3-empty-arg (guard, pre-impl PASS): empty third arg exits 0, review_max_severity == \"None\", append occurs" \
  "[ '$RUN_EXIT' -eq 0 ] && [ '$RUN_LINE_COUNT' -eq 2 ] && printf '%s' '$RUN_LINE2' | jq -e '.review_max_severity == \"None\"' >/dev/null 2>&1"

run_fixture missing
assert_true "AC3-nonexistent-path (guard, pre-impl PASS): nonexistent findings path exits 0, review_max_severity == \"None\", append occurs" \
  "[ '$RUN_EXIT' -eq 0 ] && [ '$RUN_LINE_COUNT' -eq 2 ] && printf '%s' '$RUN_LINE2' | jq -e '.review_max_severity == \"None\"' >/dev/null 2>&1"

# =============================================================================
echo ""
echo "=== AC4 (fail-loud discrimination witness, incl. clean-None-present, guard) ==="
# =============================================================================
# Proves AC2's block fires ONLY on the unparseable-present case, not on every
# present findings file. Both fixtures already resolve correctly under the
# as-is colon grammar, so this is a guard (PASS pre-impl) — its value is
# pairing against AC2's negative, which only becomes meaningful post-fix.

run_fixture content 'max_severity: Medium'
assert_true "AC4-valid-colon (guard, pre-impl PASS): a present file with a valid colon max_severity still emits normally (exit 0, append, correct enum)" \
  "[ '$RUN_EXIT' -eq 0 ] && [ '$RUN_LINE_COUNT' -eq 2 ] && printf '%s' '$RUN_LINE2' | jq -e '.review_max_severity == \"Medium\"' >/dev/null 2>&1"

run_fixture content 'max_severity: None'
assert_true "AC4-clean-None-present (guard, pre-impl PASS, highest over-block risk under boundary B): a present file carrying max_severity: None resolves to None and takes the exit-0 append path (NOT fail-loud)" \
  "[ '$RUN_EXIT' -eq 0 ] && [ '$RUN_LINE_COUNT' -eq 2 ] && printf '%s' '$RUN_LINE2' | jq -e '.review_max_severity == \"None\"' >/dev/null 2>&1"

# =============================================================================
echo ""
echo "=== AC5 (Approach 1, producer-contract pin, RED, doc-assertion) ==="
# =============================================================================

STEP65_BLOCK="$(extract_step '^6\.5\.' '^6\.7\.' "$GUIDE_MD")"
STEP67_BLOCK="$(extract_step '^6\.7\.' '^7\.' "$GUIDE_MD")"
export STEP65_BLOCK STEP67_BLOCK

assert_true "AC5-precondition: HANDOFF step 6.5 block is non-empty (locatable in docs/autoflow-guide.md)" \
  "[ -n \"\$STEP65_BLOCK\" ]"
assert_true "AC5-precondition: HANDOFF step 6.7 block is non-empty (locatable in docs/autoflow-guide.md)" \
  "[ -n \"\$STEP67_BLOCK\" ]"

assert_true "AC5-notation (RED): step 6.5 pins the normative on-disk notation form 'max_severity: <value>' for the review-findings file" \
  "printf '%s' \"\$STEP65_BLOCK\" | grep -qE 'max_severity:[[:space:]]*<[^>]*>'"

assert_true "AC5-presence (RED): step 6.5 pins the mandatory PRESENCE of the max_severity line — the sub-agent always writes exactly one, including on a clean review (=> None)" \
  "printf '%s' \"\$STEP65_BLOCK\" | grep -qiF '[MUST]' \
   && printf '%s' \"\$STEP65_BLOCK\" | grep -qiE 'always[^.]*(writes?|emits?|include)[^.]*max_severity' \
   && printf '%s' \"\$STEP65_BLOCK\" | grep -qiE 'clean review'"

assert_true "AC5-failloud-doc (RED): step 6.7 discloses that a present-but-unparseable max_severity now blocks digest emission (fail-loud) rather than defaulting to None" \
  "printf '%s' \"\$STEP67_BLOCK\" | grep -qiE 'unparseable|cannot be resolved|not resolve|unresolvable' \
   && printf '%s' \"\$STEP67_BLOCK\" | grep -qiE 'non-zero exit|aborts?|fail-loud'"

# =============================================================================
echo ""
echo "=== AC6 (no-regression guard) — existing #953 emitter suite (F7/F7b/RR2) must stay green ==="
# =============================================================================

if [ -x "$DIGEST_953_SUITE" ]; then
  bash "$DIGEST_953_SUITE" >/tmp/issue-6-ac6-953-rerun-$$.log 2>&1
  AC6_EXIT=$?
  rm -f "/tmp/issue-6-ac6-953-rerun-$$.log"
  assert_true "AC6 (guard, pre-impl PASS): bash tests/test-issue-953-cycle-digest.sh exits 0 (0 failures) — grammar/fail-loud change must not regress F7/F7b/RR2" \
    "[ '$AC6_EXIT' -eq 0 ]"
else
  assert_true "AC6-precondition: tests/test-issue-953-cycle-digest.sh exists and is executable" "false"
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
