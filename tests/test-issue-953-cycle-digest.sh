#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: per-cycle digest data plane — Issue #953
# =============================================================================
# Tier-1 scripted assertion suite per verification design
# (.autoflow/issue-953-verification-design.md). Docs/ops + hook + manifest
# change (no jest, no npm) — mirrors tests/test-issue-955-subagent-background-ban.sh
# / tests/test-issue-949-manifest-regen-doc.sh / tests/test-issue-800-doc-assertions.sh:
# assert_true/assert_false over grep/awk section extraction + jq + git + hook
# invocation.
#
# Scope (verification design §1/§7):
#   AC1 — HANDOFF playbook write-point step wording (post-6.5/pre-active:false
#         window, model-explicit sonnet autoflow-analyzer spawn, anchor+
#         one-line-summary return contract) + autoflow-analyzer.md description
#         extension.
#   AC2 — schema definition + durable git-tracked append (tracked-ness,
#         not-ignored, cleanup-glob non-match, jq schema validation of every
#         line against the F8 fixture, dogfood line-1 non-stub guard,
#         F7 emit-cycle-digest.sh append-only behavior on a fixture input,
#         run in an isolated temp copy of the repo).
#   AC3 — PR co-ride documented (update-push to the cycle's own dev branch,
#         no separate push/PR).
#   AC4 — hook malformed-state scan non-target (scan-scope assertion +
#         behavioral regression: hook invoked with the digest present does
#         not block; contrast control: the same content AS an
#         .autoflow/*.json file DOES trip the malformed-state refusal).
#   AC5 — gate-evaluation non-injection guarantee ([DENY] clause present;
#         absence from the per-role injection whitelist / ARCHITECT-onward
#         injection guidance / evaluator prompt / gate playbooks).
#   AC6 — ADR-0015 distribution-surface exclusion (manifest absence,
#         closure-link absence, ADR carve-out wording, regen idempotence in
#         an isolated temp copy).
#   AC7 — residual scope (pre-HANDOFF abort) documented + explicit-deferral
#         disposition (deferral tokens present, NO follow-up issue number
#         cited).
#
# RED expectation (pre-implementation, this commit): AC1, AC2(a-tracked,
# b-schema/dogfood, c-F7-exists), AC3, AC5, AC7 all FAIL (the step/file/clauses
# do not exist yet). AC4 and AC6's manifest/regen checks are guards that are
# vacuously satisfied pre-impl (the digest cannot be scanned or shipped
# because it does not exist) — this is the same "guard vs. RED discriminator"
# split used by tests/test-issue-949-manifest-regen-doc.sh.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GUIDE_MD="$PROJECT_ROOT/docs/autoflow-guide.md"
ANALYZER_MD="$PROJECT_ROOT/.claude/agents/autoflow-analyzer.md"
EVALUATOR_MD="$PROJECT_ROOT/.claude/agents/autoflow-evaluator.md"
ANALYSIS_MD="$PROJECT_ROOT/docs/phases/analysis.md"
INDEX_MD="$PROJECT_ROOT/docs/INDEX.md"
ADR_0015="$PROJECT_ROOT/docs/adr/0015-autoflow-distribution-plugin-plus-thin-root-layer.md"
MANIFEST_JSON="$PROJECT_ROOT/setup/manifest.json"
GEN_MANIFEST_SH="$PROJECT_ROOT/setup/gen-manifest-hashes.sh"
DESIGN_RATIONALE_MD="$PROJECT_ROOT/docs/design-rationale.md"
HOOK="$PROJECT_ROOT/.claude/hooks/check-autoflow-gate.sh"
DIGEST_JSONL="$PROJECT_ROOT/docs/cycle-digest.jsonl"
SCHEMA_FIXTURE="$PROJECT_ROOT/tests/fixtures/cycle-digest-schema.json"
EMIT_SCRIPT="$PROJECT_ROOT/scripts/handoff/emit-cycle-digest.sh"
# Pre-migration snapshot of docs/cycle-digest.jsonl (issue #979 AC-7, D2): a
# byte copy of the corpus taken at RED time, before the GREEN one-shot
# codex_max_severity -> review_max_severity migration. Lets the migration
# assertion below compare "value before" to "value after" without depending
# on the live corpus still carrying the retired field name.
DIGEST_JSONL_BACKUP="$PROJECT_ROOT/tests/fixtures/cycle-digest-979-pre-migration-snapshot.jsonl"

PASS=0; FAIL=0; TESTS=0

# ---------------------------------------------------------------------------
# Helpers (assert_* pattern per tests/test-issue-800-doc-assertions.sh /
# tests/test-issue-949-manifest-regen-doc.sh)
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
# Section extractors (mirrors tests/test-issue-949-manifest-regen-doc.sh)
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

# Bounded paragraph extractor: from a start marker line to the next blank
# line (double newline), used to scope AC5's ARCHITECT-onward injection
# guidance grep to the single paragraph, not the whole HANDOFF-carrying file
# (which legitimately mentions "cycle-digest" at the F1 write-point step).
extract_paragraph() {
  local marker="$1" file="$2"
  awk -v p="$marker" '
    $0 ~ p { f=1 }
    f { print }
    f && /^$/ && NR>1 { exit }
  ' "$file"
}

HANDOFF_BODY="$([ -f "$GUIDE_MD" ] && extract_section '^## HANDOFF' "$GUIDE_MD" || true)"
HANDOFF_JOINED="$(printf '%s' "$HANDOFF_BODY" | tr '\n' ' ')"
ARCHITECT_INJECTION_PARA="$([ -f "$GUIDE_MD" ] && extract_paragraph 'Document injection \(ARCHITECT onward\)' "$GUIDE_MD" || true)"
export HANDOFF_JOINED

echo "=== AC1 (RED discriminator) — HANDOFF write-point step wording ==="

assert_true "AC1-a: HANDOFF section names a digest-emission step (grep 'cycle digest' / 'cycle-digest')" \
  "printf '%s' \"\$HANDOFF_JOINED\" | grep -qiF 'cycle digest' || printf '%s' \"\$HANDOFF_JOINED\" | grep -qF 'cycle-digest'"
assert_true "AC1-b: HANDOFF section names docs/cycle-digest.jsonl as the append target" \
  "printf '%s' \"\$HANDOFF_JOINED\" | grep -qF 'docs/cycle-digest.jsonl'"
assert_true "AC1-c: HANDOFF section declares an explicit model:\"sonnet\" spawn (Spawn Model [MUST])" \
  "printf '%s' \"\$HANDOFF_JOINED\" | grep -qF 'model' && printf '%s' \"\$HANDOFF_JOINED\" | grep -qF 'sonnet'"
assert_true "AC1-d: HANDOFF section names the autoflow-analyzer subagent_type (declared-role gate compliance)" \
  "printf '%s' \"\$HANDOFF_JOINED\" | grep -qF 'autoflow-analyzer'"
assert_true "AC1-e: HANDOFF section states an anchor + one-line-summary return contract" \
  "printf '%s' \"\$HANDOFF_JOINED\" | grep -qiF 'anchor' && printf '%s' \"\$HANDOFF_JOINED\" | grep -qiF 'one-line'"
assert_true "AC1-f: .claude/agents/autoflow-analyzer.md description names the cycle-digest emission variant" \
  "[ -f '$ANALYZER_MD' ] && grep -qiF 'cycle digest' '$ANALYZER_MD' || grep -qF 'cycle-digest' '$ANALYZER_MD' 2>/dev/null"

echo ""
echo "=== AC1 ordering (RED discriminator) — step is positioned after 6.5, before step 7 (active:false) ==="
# Ordering by line position of the digest-step anchor vs the 6.5 / step-7
# (active:false) anchors within the HANDOFF block, per verification design
# AC1 method 1 (awk section extraction, line-position comparison).

assert_true "AC1-order: a 'cycle digest' / 'cycle-digest' anchor line appears AFTER the '6.5' review-triage anchor line and BEFORE the step-7 'active' to 'false' anchor line" \
  "awk 'BEGIN{f=0} \$0 ~ /^## HANDOFF/{f=1;next} f && /^## /{exit} f{print NR\": \"\$0}' '$GUIDE_MD' \
    | awk -F: '
        /6\\.5/ {p65=\$1}
        /[Cc]ycle[- ][Dd]igest/ {pdig=\$1}
        /active.*false/ {p7=\$1}
        END { exit !(pdig!=\"\" && p65!=\"\" && p7!=\"\" && pdig+0>p65+0 && pdig+0<p7+0) }
      '"

echo ""
echo "=== AC2 (RED discriminator) — schema definition + durable git-tracked append ==="

assert_true "AC2-tracked: docs/cycle-digest.jsonl is git-tracked (git ls-files --error-unmatch, the real state-flip)" \
  "git ls-files --error-unmatch docs/cycle-digest.jsonl >/dev/null 2>&1"

assert_true "AC2-not-ignored: docs/cycle-digest.jsonl is NOT matched by .gitignore (supporting guard; no docs/ ignore rule exists today)" \
  "! git check-ignore -q docs/cycle-digest.jsonl"

assert_true "AC2-ignore-contrast: contrast control — .autoflow/issue-1.json IS gitignored (confirms check-ignore is discriminating, not universally non-zero)" \
  "git check-ignore -q .autoflow/issue-1.json"

assert_true "AC2-cleanup-scope: docs/cycle-digest.jsonl does not match the PREFLIGHT cleanup glob '.autoflow/issue-{N}*'" \
  "case 'docs/cycle-digest.jsonl' in .autoflow/issue-*) false;; *) true;; esac"

if [ -f "$DIGEST_JSONL" ]; then
  assert_true "AC2-parse: every line of docs/cycle-digest.jsonl is valid JSON (jq -c .)" \
    "jq -c . '$DIGEST_JSONL' >/dev/null 2>&1"

  if [ -f "$SCHEMA_FIXTURE" ]; then
    assert_true "AC2-schema: every line's top-level keys are a subset of the F8 fixture's declared top_level_keys (canonical field names)" \
      "jq -e --slurpfile schema '$SCHEMA_FIXTURE' -n '
        [inputs] as \$lines
        | \$schema[0].top_level_keys as \$allowed
        | (\$lines | map((keys_unsorted - \$allowed) | length == 0) | all)
      ' '$DIGEST_JSONL' >/dev/null 2>&1"

    assert_true "AC2-gate-shape: every gate value has(\"pass\") or has(\"verdict\") (verdict-only gate_hypothesis_cause handled)" \
      "jq -e --slurpfile schema '$SCHEMA_FIXTURE' -n '
        [inputs] as \$lines
        | \$lines | map(.gates // {} | to_entries | map(.value | has(\"pass\") or has(\"verdict\")) | all) | all
      ' '$DIGEST_JSONL' >/dev/null 2>&1"

    assert_true "AC2-escaped-defects-array: every line's escaped_defects is an array (may be empty)" \
      "jq -e -n '[inputs] as \$lines | \$lines | map(.escaped_defects | type == \"array\") | all' '$DIGEST_JSONL' >/dev/null 2>&1"

    assert_true "AC2-severity-enum (issue #979 AC-7 rename): every line's review_max_severity is one of the F8 enum" \
      "jq -e --slurpfile schema '$SCHEMA_FIXTURE' -n '
        [inputs] as \$lines
        | \$schema[0].review_max_severity_enum as \$enum
        | \$lines | map(.review_max_severity as \$s | \$enum | index(\$s) != null) | all
      ' '$DIGEST_JSONL' >/dev/null 2>&1"

    assert_true "AC2-dogfood-non-stub (DR6): line 1's gates.gate_plan.avg is a real score (> 0), not the illustration placeholder" \
      "jq -e 'select(.gates.gate_plan.avg != null) | .gates.gate_plan.avg > 0' <(head -n1 '$DIGEST_JSONL') >/dev/null 2>&1"

    # -------------------------------------------------------------------------
    # AC-7 (issue #979, D2) — one-shot value-preserving corpus migration.
    # docs/cycle-digest.jsonl is captured as its pre-migration snapshot ($comment
    # anchor: this repo's live corpus at RED time carries codex_max_severity on
    # every one of its 5 lines — confirmed by grep prior to writing this test).
    # Post-GREEN-migration the corpus must carry review_max_severity with the
    # SAME value on every line and codex_max_severity must be gone.
    # -------------------------------------------------------------------------
    assert_true "AC7-migration-no-old-field: no docs/cycle-digest.jsonl line carries the retired codex_max_severity key" \
      "! grep -q 'codex_max_severity' '$DIGEST_JSONL'"
    assert_true "AC7-migration-value-preserving: the migrated prefix (first snapshot-length lines) of $DIGEST_JSONL still has review_max_severity equal to its own codex_max_severity_before value captured pre-migration ($DIGEST_JSONL_BACKUP); lines appended after migration are out of this assertion's scope" \
      "jq -e -n --slurpfile before '$DIGEST_JSONL_BACKUP' '
        [inputs] as \$after
        | (\$before | length) <= (\$after | length)
        and ([range(0; \$before|length)] | map(\$before[.].codex_max_severity == \$after[.].review_max_severity) | all)
      ' '$DIGEST_JSONL' >/dev/null 2>&1"
  else
    assert_true "AC2-schema-fixture-missing: tests/fixtures/cycle-digest-schema.json exists (F8)" "false"
  fi
else
  assert_true "AC2-file-exists: docs/cycle-digest.jsonl exists" "false"
  echo "  SKIP: AC2-parse/AC2-schema/AC2-gate-shape/AC2-escaped-defects-array/AC2-severity-enum/AC2-dogfood-non-stub (file absent pre-impl)"
  TESTS=$((TESTS + 6))
fi

echo ""
echo "=== AC2 / DR1 — F7 emit-cycle-digest.sh append-only behavior (isolated temp copy, no live HANDOFF) ==="

if [ -x "$EMIT_SCRIPT" ]; then
  assert_true "AC2-F7-append-op: emit-cycle-digest.sh uses '>>' append redirection targeting cycle-digest.jsonl" \
    "grep -qF '>>' '$EMIT_SCRIPT' && grep -qF 'cycle-digest.jsonl' '$EMIT_SCRIPT'"
  assert_false "AC2-F7-no-truncate: emit-cycle-digest.sh does not truncate-write the digest (no bare single '>' redirect to cycle-digest.jsonl)" \
    "grep -E '[^>]>[^>][^&]*cycle-digest\\.jsonl' '$EMIT_SCRIPT' | grep -qv '>>'"

  TMP_REPO="$(mktemp -d)"
  (cd "$PROJECT_ROOT" && tar --exclude='.git' -cf - .) | (cd "$TMP_REPO" && tar -xf -) 2>/dev/null
  mkdir -p "$TMP_REPO/.autoflow" "$TMP_REPO/docs"
  SEED_LINE='{"issue":"#0","terminal_cycle":1,"date":"2026-01-01","mode":"new-issue","gates":{"gate_hypothesis_structure":{"pass":true,"avg":7.5,"items":{},"below7":[]},"gate_hypothesis_cause":{"verdict":"skipped (feat issue)"},"gate_plan":{"pass":true,"avg":8.0,"items":{},"below7":[]},"audit":{"pass":true,"avg":8.0,"items":{},"below7":[]},"gate_quality":{"pass":true,"avg":8.0,"items":{},"below7":[]}},"regressions":{"gate_plan":0,"verify":0,"audit":0,"gate_quality":0,"review_autofix_cycles":0},"architect":{"rounds":0,"escalate":false},"loop_check_class":null,"codex_max_severity":"None","escaped_defects":[]}'
  printf '%s\n' "$SEED_LINE" > "$TMP_REPO/docs/cycle-digest.jsonl"

  cat > "$TMP_REPO/.autoflow/issue-0.json" <<'EOF'
{ "active": true, "issue": "#0", "title": "fixture", "date": "2026-01-01", "cycle": 1, "mode": "new-issue",
  "phases": {
    "gate_hypothesis_structure": {"scores": {"a": {"score": 7.5}}},
    "gate_hypothesis_cause": {"verdict": "skipped (feat issue)"},
    "gate_plan": {"scores": {"a": {"score": 8}, "b": {"score": 8}}},
    "audit": {"scores": {"a": {"score": 8}}},
    "gate_quality": {"scores": {"a": {"score": 8}}}
  }
}
EOF
  printf '# Ledger\n- ARCHITECT rounds: 0, escalate: false\n- loop_check_class: none\n' > "$TMP_REPO/.autoflow/issue-0-ledger.md"
  printf '# Review findings\nmax_severity: None\nescaped_defects: []\n' > "$TMP_REPO/.autoflow/issue-0-review-findings.md"

  ( cd "$TMP_REPO" && bash scripts/handoff/emit-cycle-digest.sh \
      .autoflow/issue-0.json .autoflow/issue-0-ledger.md .autoflow/issue-0-review-findings.md \
      >/tmp/f7-out-$$.log 2>&1 )
  F7_EXIT=$?

  assert_true "AC2-F7-exit0: F7 exits 0 against fixture inputs in an isolated copy" \
    "[ '$F7_EXIT' -eq 0 ]"
  assert_true "AC2-F7-line-count: docs/cycle-digest.jsonl grows to exactly 2 lines (append, not overwrite)" \
    "[ \"\$(wc -l < '$TMP_REPO/docs/cycle-digest.jsonl' | tr -d ' ')\" = '2' ]"
  assert_true "AC2-F7-line1-unchanged: line 1 is byte-unchanged after the append" \
    "[ \"\$(sed -n '1p' '$TMP_REPO/docs/cycle-digest.jsonl')\" = '$SEED_LINE' ]"

  rm -rf "$TMP_REPO" "/tmp/f7-out-$$.log" 2>/dev/null

  # -------------------------------------------------------------------------
  # Findings-carrying leg (VERIFY step-3 ruling — escaped_defects RED): a
  # Medium+ review cycle's terminal record must carry a POPULATED
  # escaped_defects array; the feature-design §4 schema and the F8 fixture's
  # escaped_defect_item_keys define the item shape
  # {class, nominal_rubric_item, surface, codex_anchor}.
  # Input grammar: the emitter's accepted findings-file format is tolerant
  # `key: value` line greps (scripts/handoff/emit-cycle-digest.sh:51-71 —
  # `max_severity: <Sev>` is already parsed exactly that way); the per-finding
  # source fields (severity + file:line surface) mirror what the HANDOFF
  # step-6.5 review-triage subagent classifies from the Codex review comment,
  # whose required finding fields are defined in .codex/review.md:82-88
  # (Severity, File and line reference). The fixture states one Medium
  # finding as an indented `key: value` block under a `- severity:` list
  # entry — extending the same line-grammar the emitter already accepts.
  # -------------------------------------------------------------------------
  TMP_REPO2="$(mktemp -d)"
  (cd "$PROJECT_ROOT" && tar --exclude='.git' -cf - .) | (cd "$TMP_REPO2" && tar -xf -) 2>/dev/null
  mkdir -p "$TMP_REPO2/.autoflow" "$TMP_REPO2/docs"
  printf '%s\n' "$SEED_LINE" > "$TMP_REPO2/docs/cycle-digest.jsonl"

  cat > "$TMP_REPO2/.autoflow/issue-0.json" <<'EOF'
{ "active": true, "issue": "#0", "title": "fixture", "date": "2026-01-01", "cycle": 2, "mode": "review-response",
  "phases": {
    "gate_hypothesis_structure": {"scores": {"a": {"score": 7.5}}},
    "gate_hypothesis_cause": {"verdict": "skipped (feat issue)"},
    "gate_plan": {"scores": {"a": {"score": 8}, "b": {"score": 8}}},
    "audit": {"scores": {"a": {"score": 8}}},
    "gate_quality": {"scores": {"a": {"score": 8}}}
  }
}
EOF
  printf '# Ledger\n- ARCHITECT rounds: 1, escalate: false\n- review-autofix entry (cycle 2)\n' > "$TMP_REPO2/.autoflow/issue-0-ledger.md"
  cat > "$TMP_REPO2/.autoflow/issue-0-review-findings.md" <<'EOF'
# Review findings (fixture — Medium-carrying cycle)
max_severity: Medium

## Findings
- severity: Medium
  class: mock-boundary-drift
  nominal_rubric_item: test_coverage_quality
  surface: api/server/routes/example.js:42
  codex_anchor: https://github.com/example/repo/pull/1#discussion_r001
EOF

  ( cd "$TMP_REPO2" && bash scripts/handoff/emit-cycle-digest.sh \
      .autoflow/issue-0.json .autoflow/issue-0-ledger.md .autoflow/issue-0-review-findings.md \
      >/dev/null 2>&1 )
  F7B_EXIT=$?
  F7B_LINE2="$(sed -n '2p' "$TMP_REPO2/docs/cycle-digest.jsonl" 2>/dev/null)"
  export F7B_LINE2

  assert_true "AC2-F7b-exit0: F7 exits 0 against a findings-carrying (Medium) fixture" \
    "[ '$F7B_EXIT' -eq 0 ]"
  assert_true "AC2-F7b-severity (issue #979 AC-7 rename): emitted record's review_max_severity reflects the fixture's Medium (guard — max_severity parsing pre-exists at emit-cycle-digest.sh:71)" \
    "printf '%s' \"\$F7B_LINE2\" | jq -e '.review_max_severity == \"Medium\"' >/dev/null 2>&1"
  assert_true "AC2-F7b-escaped-nonempty (RED): a Medium-carrying findings input yields a NON-EMPTY escaped_defects array" \
    "printf '%s' \"\$F7B_LINE2\" | jq -e '.escaped_defects | length > 0' >/dev/null 2>&1"
  assert_true "AC2-F7b-escaped-item-keys (RED): every escaped_defects item's keys equal the F8 fixture's escaped_defect_item_keys" \
    "printf '%s' \"\$F7B_LINE2\" | jq -e --slurpfile schema '$SCHEMA_FIXTURE' '
      (\$schema[0].escaped_defect_item_keys | sort) as \$want
      | (.escaped_defects | length > 0)
        and (.escaped_defects | map((keys_unsorted | sort) == \$want) | all)
    ' >/dev/null 2>&1"

  rm -rf "$TMP_REPO2"

  # -------------------------------------------------------------------------
  # RR2 (Codex Medium, PR #969) — bare-number / mixed-shape score
  # normalization regression guard. AC-RR2-1 (verification design
  # .autoflow/issue-953-rr2-verification-design.md §2): the gate hook accepts
  # BOTH the object score shape {"score": N} and the bare-number shape "a": N
  # (tests/test-issue-245-schema-validation.sh:327-338); the emitter must
  # normalize both at every `.value.score` site ($vals/$below/items). This
  # fixture packs three discriminating gates into one hook-valid state file:
  #   gate_plan   — PURE bare-number scores  {"a": 8, "b": 6}
  #   audit       — INTRA-GATE MIXED scores  {"a": 8, "b": {"score": 6}}
  #   gate_quality— object-form (no-regression witness) {"a": {"score": 8}}
  # Pre-fix, gate_plan's bare `8` crashes `.value.score` (jq: Cannot index
  # number with "score") under `set -euo pipefail`, aborting the whole
  # `jq -c -n` before the append — RED discriminator is emitter exit 0 (this
  # fails on HEAD; the line-2 field assertions fail vacuously alongside it).
  # -------------------------------------------------------------------------
  TMP_REPO3="$(mktemp -d)"
  (cd "$PROJECT_ROOT" && tar --exclude='.git' -cf - .) | (cd "$TMP_REPO3" && tar -xf -) 2>/dev/null
  mkdir -p "$TMP_REPO3/.autoflow" "$TMP_REPO3/docs"
  printf '%s\n' "$SEED_LINE" > "$TMP_REPO3/docs/cycle-digest.jsonl"

  cat > "$TMP_REPO3/.autoflow/issue-0.json" <<'EOF'
{ "active": true, "issue": "#0", "title": "fixture", "date": "2026-01-01", "cycle": 1, "mode": "new-issue",
  "phases": {
    "gate_hypothesis_structure": {"scores": {"a": {"score": 7.5}}},
    "gate_hypothesis_cause": {"verdict": "skipped (feat issue)"},
    "gate_plan": {"scores": {"a": 8, "b": 6}},
    "audit": {"scores": {"a": 8, "b": {"score": 6}}},
    "gate_quality": {"scores": {"a": {"score": 8}}}
  }
}
EOF
  printf '# Ledger\n- ARCHITECT rounds: 0, escalate: false\n- loop_check_class: none\n' > "$TMP_REPO3/.autoflow/issue-0-ledger.md"
  printf '# Review findings\nmax_severity: None\nescaped_defects: []\n' > "$TMP_REPO3/.autoflow/issue-0-review-findings.md"

  ( cd "$TMP_REPO3" && bash scripts/handoff/emit-cycle-digest.sh \
      .autoflow/issue-0.json .autoflow/issue-0-ledger.md .autoflow/issue-0-review-findings.md \
      >/tmp/rr2-out-$$.log 2>&1 )
  RR2_EXIT=$?
  RR2_LINE2="$(sed -n '2p' "$TMP_REPO3/docs/cycle-digest.jsonl" 2>/dev/null)"
  export RR2_LINE2

  assert_true "AC-RR2-1-exit0 (RED): emitter exits 0 on a hook-valid state file mixing bare-number and object score shapes (pre-fix: exit 5 jq crash on .value.score)" \
    "[ '$RR2_EXIT' -eq 0 ]"
  assert_true "AC-RR2-1-line-count (RED): docs/cycle-digest.jsonl grows to exactly 2 lines (no crash before the append)" \
    "[ \"\$(wc -l < '$TMP_REPO3/docs/cycle-digest.jsonl' | tr -d ' ')\" = '2' ]"
  assert_true "AC-RR2-1-bare-gate (RED): gate_plan (pure bare-number scores) derives avg==7, items.a==8, items.b==6, below7==[\"b\"], pass==false" \
    "printf '%s' \"\$RR2_LINE2\" | jq -e '.gates.gate_plan | .avg == 7 and .items.a == 8 and .items.b == 6 and .below7 == [\"b\"] and .pass == false' >/dev/null 2>&1"
  assert_true "AC-RR2-1-mixed-gate (RED): audit (intra-gate mixed bare + object scores) derives below7==[\"b\"], pass==false, items.a==8, items.b==6" \
    "printf '%s' \"\$RR2_LINE2\" | jq -e '.gates.audit | .below7 == [\"b\"] and .pass == false and .items.a == 8 and .items.b == 6' >/dev/null 2>&1"
  assert_true "AC-RR2-1-object-gate (no-regression witness): gate_quality (object-form scores) still derives items.a==8" \
    "printf '%s' \"\$RR2_LINE2\" | jq -e '.gates.gate_quality.items.a == 8' >/dev/null 2>&1"

  rm -rf "$TMP_REPO3" "/tmp/rr2-out-$$.log" 2>/dev/null
else
  assert_true "AC2-F7-exists: scripts/handoff/emit-cycle-digest.sh exists and is executable" "false"
  echo "  SKIP: AC2-F7-append-op/no-truncate/exit0/line-count/line1-unchanged + F7b findings-carrying leg + RR2 bare-number/mixed-shape leg (script absent pre-impl)"
  TESTS=$((TESTS + 14))
fi

echo ""
echo "=== AC3 (RED discriminator) — PR co-ride (update-push, no separate PR) ==="

assert_true "AC3-a: HANDOFF section states the digest rides the cycle's own dev branch / existing PR (update-push)" \
  "printf '%s' \"\$HANDOFF_JOINED\" | grep -qiE 'update.push|updates the (existing|open) PR|same (dev branch|PR)'"
assert_false "AC3-b: HANDOFF digest step does NOT introduce a separate push/PR command for the digest (no new 'gh pr create' bound to the digest step)" \
  "printf '%s' \"\$HANDOFF_JOINED\" | grep -qiE 'separate (pr|push)|second pr|new pr for.*digest'"

echo ""
echo "=== AC4 (RED discriminator/regression) — hook malformed-state scan cannot reach the digest ==="

assert_true "AC4-scan-glob: hook state-discovery glob is still \"\$AUTOFLOW_DIR\"/*.json" \
  "grep -qF '\"\$AUTOFLOW_DIR\"/*.json' '$HOOK'"
assert_true "AC4-dir-def: AUTOFLOW_DIR is still .../.autoflow" \
  "grep -qE 'AUTOFLOW_DIR=.*\\.autoflow\"?\$' '$HOOK'"
assert_true "AC4-path-shape: docs/cycle-digest.jsonl is structurally outside .autoflow/ and is not a .json file" \
  "case 'docs/cycle-digest.jsonl' in .autoflow/*) false;; *.json) false;; *) true;; esac"

# Behavioral regression: build a PASSING active-state fixture project dir,
# drop docs/cycle-digest.jsonl into it (arbitrary content), and confirm the
# hook does not block a git push on account of the digest file.
AC4_PDIR="$(mktemp -d)"
mkdir -p "$AC4_PDIR/.autoflow" "$AC4_PDIR/docs"
cat > "$AC4_PDIR/.autoflow/issue-953.json" <<'EOF'
{ "active": true, "issue": "#953",
  "phases": {
    "gate_hypothesis_cause": {"verdict": "skipped (feat issue)"},
    "gate_plan":    {"scores": {"a": {"score": 8}, "b": {"score": 8}}},
    "audit":        {"scores": {"a": {"score": 8}, "b": {"score": 8}}},
    "gate_quality": {"scores": {"a": {"score": 8}, "b": {"score": 8}}} } }
EOF
printf 'not even valid json for a digest line, on purpose\n{"issue":"#953"}\n' > "$AC4_PDIR/docs/cycle-digest.jsonl"
AC4_JSON='{"tool_name":"Bash","tool_input":{"command":"git push -u origin dev/test"}}'
AC4_EXIT=$(printf '%s' "$AC4_JSON" | CLAUDE_PROJECT_DIR="$AC4_PDIR" bash "$HOOK" >/dev/null 2>&1; echo $?)
assert_true "AC4-no-block: hook does NOT block git push when docs/cycle-digest.jsonl is present alongside a passing active state" \
  "[ '$AC4_EXIT' -eq 0 ]"

# Contrast control: the SAME arbitrary content placed as a *.json file INSIDE
# .autoflow/ (with NO other valid active state file present, mirroring the
# MALFORMED fixture in tests/test-gate-hardening.sh) trips the malformed-state
# refusal (verification design AC4 contrast control) — this isolates the
# malformed-content effect from the "another valid active file already
# satisfies the scan" case exercised by AC4-no-block above.
AC4_CONTROL_PDIR="$(mktemp -d)"
mkdir -p "$AC4_CONTROL_PDIR/.autoflow"
printf 'not even valid json for a digest line, on purpose\n' > "$AC4_CONTROL_PDIR/.autoflow/cycle-digest.json"
AC4_CONTROL_EXIT=$(printf '%s' "$AC4_JSON" | CLAUDE_PROJECT_DIR="$AC4_CONTROL_PDIR" bash "$HOOK" >/dev/null 2>&1; echo $?)
assert_true "AC4-contrast-control: the same arbitrary content AS an .autoflow/*.json file (no other valid active state) DOES trip the malformed-state block (exit 2), proving the digest's chosen location is what dodges it" \
  "[ '$AC4_CONTROL_EXIT' -eq 2 ]"

rm -rf "$AC4_PDIR" "$AC4_CONTROL_PDIR"

echo ""
echo "=== AC5 (RED discriminator, bounded) — gate-evaluation non-injection guarantee ==="

assert_true "AC5-deny-clause: HANDOFF digest step carries an explicit [DENY] clause naming the digest + gate/evaluation" \
  "printf '%s' \"\$HANDOFF_JOINED\" | grep -qF '[DENY]' && printf '%s' \"\$HANDOFF_JOINED\" | grep -qiE 'gate|evaluation'"

# Narrowed to the whitelist BLOCK (issue #954 INTEGRATE reconciliation): the
# #954 AC7-mandated non-conflation paragraph (analysis.md, loop-check ↔
# cross-issue scan relationship) legitimately names cycle-digest — as an
# explicit never-reads statement, the OPPOSITE of routing. The guard's intent
# is only that the per-role injection WHITELIST does not route the digest, so
# the grep is scoped from the '**Per-role document injection whitelist**'
# marker to the next top-level bold/section boundary (same awk section-
# extraction style as extract_section/extract_paragraph above).
WHITELIST_BLOCK="$([ -f "$ANALYSIS_MD" ] && awk '
  /^\*\*Per-role document injection whitelist\*\*/ { f=1; print; next }
  f && (/^\*\*/ || /^## /) { exit }
  f { print }
' "$ANALYSIS_MD" || true)"
export WHITELIST_BLOCK
assert_true "AC5-whitelist-block-nonempty (guard): the Per-role injection whitelist block was extracted (marker present, block non-empty)" \
  "[ -n \"\$WHITELIST_BLOCK\" ]"
assert_false "AC5-whitelist-analysis: docs/phases/analysis.md per-role injection whitelist does not name cycle-digest" \
  "grep -qi 'cycle.digest' <<<\"\$WHITELIST_BLOCK\""
assert_false "AC5-whitelist-index: docs/INDEX.md router does not name cycle-digest as an injectable document" \
  "[ -f '$INDEX_MD' ] && grep -qi 'cycle.digest' '$INDEX_MD'"
assert_false "AC5-architect-onward: the 'Document injection (ARCHITECT onward)' paragraph does not name cycle-digest" \
  "printf '%s' \"\$ARCHITECT_INJECTION_PARA\" | grep -qi 'cycle.digest'"
assert_false "AC5-evaluator-prompt: .claude/agents/autoflow-evaluator.md does not reference cycle-digest" \
  "[ -f '$EVALUATOR_MD' ] && grep -qi 'cycle.digest' '$EVALUATOR_MD'"

echo ""
echo "=== AC6 (RED discriminator) — ADR-0015 distribution-surface exclusion ==="

assert_true "AC6-adr-carveout: ADR-0015 Host-only tier names docs/cycle-digest.jsonl as excluded from distribution" \
  "[ -f '$ADR_0015' ] && grep -qF 'cycle-digest.jsonl' '$ADR_0015'"

assert_true "AC6-manifest-absence: setup/manifest.json has no artifacts[] row sourcing docs/cycle-digest.jsonl" \
  "! jq -r '.artifacts[].source' '$MANIFEST_JSON' 2>/dev/null | grep -qF 'docs/cycle-digest.jsonl'"

assert_false "AC6-closure-link-absence: no markdown file in the manifest-closure surface (CLAUDE.md, docs/, .claude/agents/ — excluding .autoflow/ scratch and tests/) links to docs/cycle-digest.jsonl (belt-and-suspenders on top of the .md-only structural exclusion)" \
  "grep -rlnE '\\]\\([^)]*cycle-digest\\.jsonl\\)' '$PROJECT_ROOT/CLAUDE.md' '$PROJECT_ROOT/docs' '$PROJECT_ROOT/.claude/agents' --include='*.md' 2>/dev/null | grep -qF ."

echo ""
echo "=== AC6 — manifest regen idempotence (isolated temp copy, guard not RED discriminator) ==="

if [ -x "$GEN_MANIFEST_SH" ]; then
  AC6_TMP="$(mktemp -d)"
  (cd "$PROJECT_ROOT" && tar --exclude='.git' -cf - .) | (cd "$AC6_TMP" && tar -xf -) 2>/dev/null
  ( cd "$AC6_TMP" && bash setup/gen-manifest-hashes.sh >/dev/null 2>&1 )
  assert_true "AC6-regen-idempotence: a fresh setup/gen-manifest-hashes.sh regen (isolated copy) still excludes docs/cycle-digest.jsonl" \
    "! jq -r '.artifacts[].source' '$AC6_TMP/setup/manifest.json' 2>/dev/null | grep -qF 'docs/cycle-digest.jsonl'"
  rm -rf "$AC6_TMP"
else
  assert_true "AC6-regen-script-exists: setup/gen-manifest-hashes.sh exists and is executable" "false"
fi

echo ""
echo "=== AC7 (RED discriminator) — residual scope (pre-HANDOFF abort) + explicit-deferral disposition ==="

assert_true "AC7-scope-note: HANDOFF section (or design-rationale Known Limitations) names pre-HANDOFF-abort / HANDOFF-unreached cycles as out of this write-point's reach (specific token combo — 'pre-HANDOFF'/'HANDOFF-unreached' AND 'abort', not the generic 'escalate' wording already present elsewhere in HANDOFF)" \
  "{ printf '%s' \"\$HANDOFF_JOINED\" | grep -qiE 'pre-handoff|handoff-unreached' && printf '%s' \"\$HANDOFF_JOINED\" | grep -qiF 'abort'; } \
   || { [ -f '$DESIGN_RATIONALE_MD' ] && grep -qiE 'pre-handoff|handoff-unreached' '$DESIGN_RATIONALE_MD' && grep -qiF 'abort' '$DESIGN_RATIONALE_MD'; }"

assert_true "AC7-deferral-tokens: the residual-scope note states explicit in-place deferral (no follow-up filed now) — specific phrase, not the generic 'deferred' wording already present elsewhere in HANDOFF" \
  "printf '%s' \"\$HANDOFF_JOINED\" | grep -qiE 'deferred in.place' && printf '%s' \"\$HANDOFF_JOINED\" | grep -qiE 'no follow.up'"

assert_false "AC7-no-followup-cited: the residual-scope note does NOT cite a follow-up issue number (the prior stale 'a filed follow-up issue' form is superseded per D-953-F/DR5)" \
  "printf '%s' \"\$HANDOFF_JOINED\" | grep -qiE 'follow.up.{0,40}#[0-9]+|filed as #[0-9]+'"

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
