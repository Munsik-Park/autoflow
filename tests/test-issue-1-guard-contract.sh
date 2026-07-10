#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Test: cycle-digest guard contract conflict — Issue #1 (RED meta-suite)
# =============================================================================
# Tier-1 scripted assertion suite per verification design
# (.autoflow/issue-1-verification-design.md). This suite does NOT modify
# tests/test-issue-953-cycle-digest.sh or tests/test-issue-985-doc-assertions.sh
# (GREEN's job) — it INVOKES them (on the live tree, and in isolated
# `mktemp -d` temp copies per the 953 F7 pattern) and asserts on their
# output/exit code/source text. The two target suites encode mutually
# exclusive premises about docs/cycle-digest.jsonl's lifecycle state
# (diagnosis H1); this meta-suite is the oracle that the feature design's
# guard/predicate rewrite resolves the conflict across every lifecycle state
# (empty -> this repo's own record -> inherited/internal record), never
# mutating the tracked live digest (D4).
#
# AC -> discriminator map (verification design §1):
#   V1 - empty-digest temp copy: AC2-dogfood-non-stub is SKIPPED (not
#        FAILED); 953 Results line reports 0 failed. Runs against a
#        make_temp_copy with docs/cycle-digest.jsonl truncated to 0 lines,
#        NOT the live tree — the live digest legitimately carries this
#        repo's own append-only cycle records and is not guaranteed empty.
#   V2 - empty-digest temp copy (same corpus as V1): AC7-migration-value-
#        preserving is SKIPPED via the .issue-prefix-vector corpus-presence
#        guard (not the [ -s ] guard); AC7-migration-no-old-field still
#        PASSes (left unwrapped).
#   V3 - live tree: AC1 becomes a content/provenance (date-floor) check, not
#        `wc -l == 0`; PASSes on the live tree regardless of digest content
#        (any record dated >= the release floor satisfies it); source no
#        longer contains the line-count predicate and does contain the
#        `--arg floor` date predicate.
#   V4 - temp-copy: an own-repo record dated >= the release floor
#        (2026-07-11) still PASSes the rewritten AC1 (the forward-looking
#        bug this issue exists to fix), incl. a boundary leg (date == floor).
#   V5 - temp-copy: an inherited/internal record (979 pre-migration snapshot,
#        dated 2026-07-09 < floor) still FAILs the rewritten AC1.
#   V6 - live tree: both suites run together exit 0 (no mutually-exclusive
#        failure).
#   V7 - temp-copy, 3 seeds: guard re-activation asymmetry. Seed A (own-repo,
#        `.issue=#1`) re-activates AC2 (PASS + negative FAIL leg) while AC7
#        correctly stays SKIP (incl. a future-own-#953 collision leg). Seed B
#        (post-migration corpus — same `.issue` prefix as the snapshot but
#        with `review_max_severity` set to the old `codex_max_severity` value
#        and `codex_max_severity` removed, per GATE:PLAN ledger E7) fires
#        AC7 -> PASS. Seed C (Seed B with one `review_max_severity` altered)
#        fires AC7 -> FAIL.
#   V8 - post-rename four-site sweep: `AC1-DIGEST-EMPTIED` has zero remaining
#        occurrences (repo-wide), and the distinct sibling ID
#        `AC1-NO-DANGLING-REF` is unaffected.
#
# RED expectation (pre-implementation, this commit): the assertions that
# exercise the not-yet-applied guard/predicate rewrite FAIL — see the RED
# report (.autoflow/issue-1-red-report.md) for the per-assertion breakdown,
# including the legitimately-already-true legs the verification design's own
# Oracle note (§3) and Round-1 discussion (V5 cannot be distinguished from V4
# by the old count predicate — both merely make the count nonzero) predict
# will NOT flip (V5's FAIL leg, Seed B/C's already-unguarded PASS/FAIL, V1/V3's
# already-PASS legs on the currently-empty live tree).
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SUITE_953="$PROJECT_ROOT/tests/test-issue-953-cycle-digest.sh"
SUITE_985="$PROJECT_ROOT/tests/test-issue-985-doc-assertions.sh"
DIGEST_JSONL_BACKUP="$PROJECT_ROOT/tests/fixtures/cycle-digest-979-pre-migration-snapshot.jsonl"
RELEASE_DATE='2026-07-11'

PASS=0; FAIL=0; TESTS=0

# ---------------------------------------------------------------------------
# Helpers (assert_* pattern per tests/test-issue-953-cycle-digest.sh /
# tests/test-issue-985-doc-assertions.sh)
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
# Temp-copy harness (953 F7 pattern): tar-copy the whole tree (minus .git)
# into a mktemp -d directory, seed docs/cycle-digest.jsonl there, run one of
# the two target suites FROM INSIDE the copy (so its own PROJECT_ROOT/
# CYCLE_DIGEST/DIGEST_JSONL resolve to the copy, never the tracked live
# file), capture output + exit code, then remove the copy. Never touches the
# real docs/cycle-digest.jsonl.
# ---------------------------------------------------------------------------

make_temp_copy() {
  local tmp
  tmp="$(mktemp -d)"
  (cd "$PROJECT_ROOT" && tar --exclude='.git' -cf - .) | (cd "$tmp" && tar -xf -) 2>/dev/null
  mkdir -p "$tmp/.autoflow" "$tmp/docs"
  printf '%s' "$tmp"
}

# Same as make_temp_copy, but also stages a minimal git index (respecting
# .gitignore) so 953's git-dependent AC2 checks (AC2-tracked / AC2-not-
# ignored / AC2-ignore-contrast — git ls-files / git check-ignore) resolve
# correctly instead of erroring "not a git repository" (used by V1, which
# asserts the whole 953 suite reports 0 failed).
make_git_temp_copy() {
  local tmp
  tmp="$(make_temp_copy)"
  ( cd "$tmp" && git init -q && git add -A ) >/dev/null 2>&1
  printf '%s' "$tmp"
}

# Seed a temp copy's digest by writing seed JSONL lines directly (used for
# V5/V7 where the seed corpus is a fixture/hand-built shape, not an
# emit-cycle-digest.sh output).
seed_digest_lines() {
  local tmp="$1" file="$2"
  cp "$file" "$tmp/docs/cycle-digest.jsonl"
}

# Seed a temp copy's digest via emit-cycle-digest.sh against a synthetic
# .autoflow/issue-*.json whose .date is the given value (used for V4 — the
# emitter copies date: $s.date verbatim, so the seeded state file's date IS
# the record's date, per feature design §5.2 Round-1 update).
emit_own_record() {
  local tmp="$1" seed_date="$2"
  cat > "$tmp/.autoflow/issue-1.json" <<EOF
{ "active": true, "issue": "#1", "title": "fixture", "date": "$seed_date", "cycle": 1, "mode": "new-issue",
  "phases": {
    "gate_hypothesis_structure": {"scores": {"a": {"score": 7.5}}},
    "gate_hypothesis_cause": {"verdict": "skipped (feat issue)"},
    "gate_plan": {"scores": {"a": {"score": 8}, "b": {"score": 8}}},
    "audit": {"scores": {"a": {"score": 8}}},
    "gate_quality": {"scores": {"a": {"score": 8}}}
  }
}
EOF
  printf '# Ledger\n- ARCHITECT rounds: 0, escalate: false\n- loop_check_class: none\n' > "$tmp/.autoflow/issue-1-ledger.md"
  printf '# Review findings\nmax_severity: None\nescaped_defects: []\n' > "$tmp/.autoflow/issue-1-review-findings.md"
  ( cd "$tmp" && bash scripts/handoff/emit-cycle-digest.sh \
      .autoflow/issue-1.json .autoflow/issue-1-ledger.md .autoflow/issue-1-review-findings.md \
      >/dev/null 2>&1 )
}

run_985_in() {
  local tmp="$1"
  ( cd "$tmp" && bash tests/test-issue-985-doc-assertions.sh 2>&1 )
}

run_953_in() {
  local tmp="$1"
  ( cd "$tmp" && bash tests/test-issue-953-cycle-digest.sh 2>&1 )
}

# =============================================================================
# V1 — empty-digest temp copy: AC2-dogfood-non-stub SKIPs, not FAILs
# =============================================================================
# NOTE: V1/V2 do NOT assume the live docs/cycle-digest.jsonl is empty — the
# live tree legitimately carries this repo's own append-only cycle records
# (per HANDOFF 6.7 digest emission) and can be non-empty at any point in the
# repo's life. AC2/AC7's SKIP-on-empty-corpus behavior is instead exercised
# against a dedicated `make_temp_copy` whose digest is truncated to 0 lines,
# so the assertion holds regardless of the live tree's current digest state
# (same class of premise-pinning bug 985 AC1 fixed in #985 — see the RED
# report for detail).
echo "=== V1 — empty-digest temp copy: AC2-dogfood-non-stub SKIP, not FAIL ==="

TMP_EMPTY="$(make_git_temp_copy)"
: > "$TMP_EMPTY/docs/cycle-digest.jsonl"
( cd "$TMP_EMPTY" && git add -A ) >/dev/null 2>&1
EMPTY_953_OUT="$(run_953_in "$TMP_EMPTY")"
export EMPTY_953_OUT
rm -rf "$TMP_EMPTY"

assert_true "V1-skip: 953 output contains a SKIP line for AC2-dogfood-non-stub on an empty (0-line) digest" \
  "printf '%s' \"\$EMPTY_953_OUT\" | grep -qF 'SKIP: AC2-dogfood-non-stub'"
assert_false "V1-no-fail: 953 output does NOT contain a FAIL line for AC2-dogfood-non-stub" \
  "printf '%s' \"\$EMPTY_953_OUT\" | grep -qE '^  FAIL: AC2-dogfood-non-stub'"
assert_true "V1-results-0-failed: 953 Results line reports 0 failed" \
  "printf '%s' \"\$EMPTY_953_OUT\" | grep -qE 'Results: [0-9]+/[0-9]+ passed, 0 failed'"

# =============================================================================
# V2 — empty-digest temp copy: AC7-migration-value-preserving SKIPs via the
# .issue-prefix-vector corpus-presence guard (not [ -s ]); AC7-no-old-field
# still PASSes.
# =============================================================================
echo ""
echo "=== V2 — empty-digest temp copy: AC7-migration-value-preserving prefix-vector SKIP ==="

assert_true "V2-skip: 953 output contains a SKIP line for AC7-migration-value-preserving on an empty (0-line) digest" \
  "printf '%s' \"\$EMPTY_953_OUT\" | grep -qF 'SKIP: AC7-migration-value-preserving'"
assert_false "V2-no-fail: 953 output does NOT contain a FAIL line for AC7-migration-value-preserving" \
  "printf '%s' \"\$EMPTY_953_OUT\" | grep -qE '^  FAIL: AC7-migration-value-preserving'"
assert_true "V2-no-old-field-still-pass: AC7-migration-no-old-field still reports PASS (left unwrapped, correct standing invariant)" \
  "printf '%s' \"\$EMPTY_953_OUT\" | grep -qE '^  PASS: AC7-migration-no-old-field'"
assert_true "V2-guard-is-prefix-vector: the AC7 guard in source is the .issue-prefix-vector match (LIVE_ISSUES/SNAP_ISSUES), not a bare [ -s ] guard" \
  "grep -qF 'LIVE_ISSUES' '$SUITE_953' && grep -qF 'SNAP_ISSUES' '$SUITE_953'"

# =============================================================================
# V3 — live tree: AC1 becomes a date-floor content/provenance check
# =============================================================================
echo ""
echo "=== V3 — AC1 content/provenance (date-floor) check, not wc -l == 0 ==="

LIVE_985_OUT="$(bash "$SUITE_985" 2>&1)"
LIVE_985_EXIT=$?
export LIVE_985_OUT

assert_true "V3-empirical-empty-pass: the date-floor predicate itself PASSes on an empty input (jq semantics, independent of wiring)" \
  "[ \"\$(printf '' | jq -e -n '[inputs] as \$l | \$l | map(.date >= \"$RELEASE_DATE\") | all')\" = 'true' ]"
assert_true "V3-floor-predicate-present: tests/test-issue-985-doc-assertions.sh's AC1 assertion contains the --arg floor date predicate" \
  "grep -qF -- '--arg floor' '$SUITE_985'"
assert_false "V3-linecount-predicate-gone: the AC1-DIGEST assertion block no longer asserts a literal wc -l line count" \
  "grep -A1 -E 'AC1-DIGEST-(EMPTIED|NO-INHERITED-RECORDS)' '$SUITE_985' | grep -qF 'wc -l'"
assert_true "V3-renamed-id-present: the assertion ID is AC1-DIGEST-NO-INHERITED-RECORDS (feature §5.4 rename)" \
  "grep -qF 'AC1-DIGEST-NO-INHERITED-RECORDS' '$SUITE_985'"

# =============================================================================
# V4 — temp-copy: an own-repo record dated >= the release floor still PASSes
# the rewritten AC1 (the forward-looking bug), incl. boundary leg (== floor).
# =============================================================================
echo ""
echo "=== V4 — own-repo record dated >= release floor still PASSes AC1 (temp-copy) ==="

TMP_V4A="$(make_temp_copy)"
emit_own_record "$TMP_V4A" "2026-07-15"
V4A_985_OUT="$(run_985_in "$TMP_V4A")"
export V4A_985_OUT
rm -rf "$TMP_V4A"

assert_true "V4-own-record-pass: an own-repo record dated after the release floor (2026-07-15) still PASSes AC1" \
  "printf '%s' \"\$V4A_985_OUT\" | grep -qE '^  PASS: AC1-DIGEST'"

TMP_V4B="$(make_temp_copy)"
emit_own_record "$TMP_V4B" "$RELEASE_DATE"
V4B_985_OUT="$(run_985_in "$TMP_V4B")"
export V4B_985_OUT
rm -rf "$TMP_V4B"

assert_true "V4-boundary-pass: an own-repo record dated exactly the release floor (2026-07-11, inclusive >=) still PASSes AC1" \
  "printf '%s' \"\$V4B_985_OUT\" | grep -qE '^  PASS: AC1-DIGEST'"

# =============================================================================
# V5 — temp-copy: an inherited/internal record (979 pre-migration snapshot,
# dated 2026-07-09 < floor) still FAILs the rewritten AC1.
# =============================================================================
echo ""
echo "=== V5 — inherited pre-migration snapshot (dated < floor) FAILs AC1 (temp-copy) ==="

TMP_V5="$(make_temp_copy)"
seed_digest_lines "$TMP_V5" "$DIGEST_JSONL_BACKUP"
V5_985_OUT="$(run_985_in "$TMP_V5")"
export V5_985_OUT
rm -rf "$TMP_V5"

assert_true "V5-inherited-fail: the inherited pre-migration snapshot corpus (all 5 lines dated 2026-07-09 < floor) FAILs AC1 — proves the date-floor check has real discriminating power" \
  "printf '%s' \"\$V5_985_OUT\" | grep -qE '^  FAIL: AC1-DIGEST'"

# =============================================================================
# V6 — live tree: both suites run together exit 0 (no mutually-exclusive
# failure). This leg is state-independent (holds for any live digest content
# ≥floor, per V3/V4) so it runs directly against the live tree, unlike
# V1/V2's empty-corpus SKIP legs above.
# =============================================================================
echo ""
echo "=== V6 — co-existence: both suites exit 0 together on the live tree ==="

bash "$SUITE_953" >/dev/null 2>&1
LIVE_953_EXIT=$?

assert_true "V6-953-exit0: tests/test-issue-953-cycle-digest.sh exits 0 on the live tree" \
  "[ '$LIVE_953_EXIT' -eq 0 ]"
assert_true "V6-985-exit0: tests/test-issue-985-doc-assertions.sh exits 0 on the live tree" \
  "[ '$LIVE_985_EXIT' -eq 0 ]"

# =============================================================================
# V7 — guard re-activation asymmetry, 3 seeds.
# =============================================================================
echo ""
echo "=== V7 — guard re-activation asymmetry (3 seeds) ==="

# --- Seed A: own-repo multi-line digest, line 1 .issue=#1 -----------------
TMP_V7A="$(make_temp_copy)"
cat > "$TMP_V7A/docs/cycle-digest.jsonl" <<'EOF'
{"issue":"#1","date":"2026-07-11","gates":{"gate_plan":{"avg":8.5}},"review_max_severity":"None"}
{"issue":"#2","date":"2026-07-11","gates":{"gate_plan":{"avg":8.0}},"review_max_severity":"None"}
EOF
V7A_953_OUT="$(run_953_in "$TMP_V7A")"
export V7A_953_OUT
rm -rf "$TMP_V7A"

assert_true "V7-seedA-ac2-runs-pass: own-repo digest (line1=#1) re-activates AC2-dogfood-non-stub and it PASSes (real gate_plan.avg=8.5>0)" \
  "printf '%s' \"\$V7A_953_OUT\" | grep -qE '^  PASS: AC2-dogfood-non-stub'"
assert_true "V7-seedA-ac7-stays-skip: own-repo digest (line1=#1) does NOT re-activate AC7-migration-value-preserving (issue vector #1,#2 != snapshot vector)" \
  "printf '%s' \"\$V7A_953_OUT\" | grep -qF 'SKIP: AC7-migration-value-preserving'"

# --- Seed A negative: own-repo digest with gate_plan.avg == 0 -------------
TMP_V7A2="$(make_temp_copy)"
cat > "$TMP_V7A2/docs/cycle-digest.jsonl" <<'EOF'
{"issue":"#1","date":"2026-07-11","gates":{"gate_plan":{"avg":0}},"review_max_severity":"None"}
EOF
V7A2_953_OUT="$(run_953_in "$TMP_V7A2")"
export V7A2_953_OUT
rm -rf "$TMP_V7A2"

assert_true "V7-seedA-ac2-negative-fail: own-repo digest with gate_plan.avg==0 (illustration-placeholder shape) FAILs AC2-dogfood-non-stub" \
  "printf '%s' \"\$V7A2_953_OUT\" | grep -qE '^  FAIL: AC2-dogfood-non-stub'"

# --- Seed A collision: line1=#953 (future own issue), lines 2-5 own -------
TMP_V7COL="$(make_temp_copy)"
cat > "$TMP_V7COL/docs/cycle-digest.jsonl" <<'EOF'
{"issue":"#953","date":"2026-07-11","gates":{"gate_plan":{"avg":8}},"review_max_severity":"None"}
{"issue":"#954","date":"2026-07-11","gates":{"gate_plan":{"avg":8}},"review_max_severity":"None"}
{"issue":"#100","date":"2026-07-11","gates":{"gate_plan":{"avg":8}},"review_max_severity":"None"}
{"issue":"#101","date":"2026-07-11","gates":{"gate_plan":{"avg":8}},"review_max_severity":"None"}
{"issue":"#102","date":"2026-07-11","gates":{"gate_plan":{"avg":8}},"review_max_severity":"None"}
EOF
V7COL_953_OUT="$(run_953_in "$TMP_V7COL")"
export V7COL_953_OUT
rm -rf "$TMP_V7COL"

assert_true "V7-collision-ac7-stays-skip: a future own #953 as line 1 (lines 2-5 own numbers, full vector != snapshot vector) does NOT re-arm AC7-migration-value-preserving" \
  "printf '%s' \"\$V7COL_953_OUT\" | grep -qF 'SKIP: AC7-migration-value-preserving'"

# --- Seed B: post-migration corpus (GATE:PLAN ledger E7 correction) -------
# Same .issue prefix as the 979 snapshot, but review_max_severity carries the
# OLD codex_max_severity value and the retired codex_max_severity key is
# REMOVED (this is what the corpus looks like AFTER the #979 migration ran —
# NOT the pre-migration fixture verbatim, which still carries
# codex_max_severity and a null review_max_severity).
TMP_V7B="$(make_temp_copy)"
cat > "$TMP_V7B/docs/cycle-digest.jsonl" <<'EOF'
{"issue":"#953","date":"2026-07-09","gates":{"gate_plan":{"avg":8}},"review_max_severity":"Medium"}
{"issue":"#954","date":"2026-07-09","gates":{"gate_plan":{"avg":8}},"review_max_severity":"None"}
{"issue":"#951","date":"2026-07-09","gates":{"gate_plan":{"avg":8}},"review_max_severity":"Low"}
{"issue":"#847","date":"2026-07-09","gates":{"gate_plan":{"avg":8}},"review_max_severity":"None"}
{"issue":"#973","date":"2026-07-09","gates":{"gate_plan":{"avg":8}},"review_max_severity":"None"}
EOF
V7B_953_OUT="$(run_953_in "$TMP_V7B")"
export V7B_953_OUT
rm -rf "$TMP_V7B"

assert_true "V7-seedB-ac7-runs-pass: the post-migration corpus (full .issue prefix vector matches the snapshot) re-activates AC7-migration-value-preserving and it PASSes" \
  "printf '%s' \"\$V7B_953_OUT\" | grep -qE '^  PASS: AC7-migration-value-preserving'"
assert_true "V7-seedB-no-old-field-pass: the post-migration corpus (codex_max_severity key removed) still PASSes AC7-migration-no-old-field" \
  "printf '%s' \"\$V7B_953_OUT\" | grep -qE '^  PASS: AC7-migration-no-old-field'"

# --- Seed C: Seed B with one review_max_severity altered (negative leg) ---
TMP_V7C="$(make_temp_copy)"
cat > "$TMP_V7C/docs/cycle-digest.jsonl" <<'EOF'
{"issue":"#953","date":"2026-07-09","gates":{"gate_plan":{"avg":8}},"review_max_severity":"Low"}
{"issue":"#954","date":"2026-07-09","gates":{"gate_plan":{"avg":8}},"review_max_severity":"None"}
{"issue":"#951","date":"2026-07-09","gates":{"gate_plan":{"avg":8}},"review_max_severity":"Low"}
{"issue":"#847","date":"2026-07-09","gates":{"gate_plan":{"avg":8}},"review_max_severity":"None"}
{"issue":"#973","date":"2026-07-09","gates":{"gate_plan":{"avg":8}},"review_max_severity":"None"}
EOF
V7C_953_OUT="$(run_953_in "$TMP_V7C")"
export V7C_953_OUT
rm -rf "$TMP_V7C"

assert_true "V7-seedC-ac7-runs-fail: the post-migration corpus with one review_max_severity altered (#953: Medium->Low) still re-activates AC7-migration-value-preserving, and it FAILs on the value mismatch" \
  "printf '%s' \"\$V7C_953_OUT\" | grep -qE '^  FAIL: AC7-migration-value-preserving'"

# =============================================================================
# V8 — post-rename four-site sweep: AC1-DIGEST-EMPTIED has zero remaining
# occurrences; the distinct sibling ID AC1-NO-DANGLING-REF is unaffected.
# =============================================================================
echo ""
echo "=== V8 — four-site rename sweep: AC1-DIGEST-EMPTIED -> AC1-DIGEST-NO-INHERITED-RECORDS ==="

assert_true "V8-old-id-gone-in-suite: grep -n AC1-DIGEST-EMPTIED tests/test-issue-985-doc-assertions.sh returns zero matches" \
  "[ -z \"\$(grep -n 'AC1-DIGEST-EMPTIED' '$SUITE_985' 2>/dev/null)\" ]"
assert_true "V8-old-id-gone-repowide: grep -rn AC1-DIGEST-EMPTIED tests/ docs/ returns zero matches (self-exclusion: this meta-suite is exempt, per 985 AC1-NO-DANGLING-REF's own-file exclusion discipline)" \
  "[ -z \"\$(git -C '$PROJECT_ROOT' grep -n 'AC1-DIGEST-EMPTIED' -- tests/ docs/ ':!tests/test-issue-1-guard-contract.sh' 2>/dev/null)\" ]"
assert_true "V8-sibling-id-distinct-unaffected: AC1-NO-DANGLING-REF still resolves as a distinct, un-renamed ID in the suite" \
  "grep -qF 'AC1-NO-DANGLING-REF' '$SUITE_985'"

# =============================================================================
# Results
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[[ $FAIL -gt 0 ]] && exit 1
exit 0
