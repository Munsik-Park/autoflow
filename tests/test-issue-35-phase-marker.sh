#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: .github/workflows/e2e-dummy-target.yml docs/autoflow-guide.md scripts/canary/emit-phase-marker.sh
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: phase-marker emitter — Issue #35
# =============================================================================
# Tier-1 scripted assertion suite per verification design
# (.autoflow/issue-35-verification-design.md, ARCHITECT round 5). Subject:
# scripts/canary/emit-phase-marker.sh, a standalone CLI that appends one JSON
# record per phase-transition marker to .autoflow/issue-<N>-phases.jsonl.
# Mirrors tests/test-issue-953-cycle-digest.sh / tests/test-issue-964-*.sh:
# assert_true/assert_false over eval'd shell conditions, PASS/FAIL/TESTS
# counters, exit 1 iff FAIL > 0.
#
# Scope (verification design §1):
#   AC1  — script exists, is executable, and tracked at git mode 100755.
#   AC2  — one JSON object appended per invocation, at the per-issue path.
#   AC3  — record carries issue/cycle/phase/event/ts/schema_version with the
#          pinned types, closed key set, whole-line shape, and a single,
#          source-pinned ts producer bounded by a [start,end] window.
#   AC4  — valid JSONL (jq -c . per line, every line an object).
#   AC5  — missing/empty required arg / non-canonical numeral / unknown
#          token -> non-zero exit, stderr message, no append (10+ arms).
#   AC6  — unrecognized/miscased --event -> non-zero, no append.
#   AC7  — repeated invocation appends; existing bytes preserved.
#   AC8  — target directory auto-created if absent, in mkdir-before-append
#          order.
#   AC9  — .autoflow/*.jsonl already gitignored (guard, vacuous at HEAD).
#   AC10 — this suite's own coverage shape (self-referential, low weight).
#   AC11 — stdout prints only a repo-relative path:line anchor, never the
#          record body.
#   E1   — inline SPDX header, both delivered .sh files (script leg here).
#   E3   — CI self-registration (e2e-dummy-target.yml paths:/run: entries).
#
# RED expectation (pre-implementation, this commit): scripts/canary does not
# exist yet, so AC1-a/b and every arm depending on invoking or reading the
# script FAIL. AC9-a/b are guards, already vacuously satisfied at HEAD
# (.gitignore:6 already covers .autoflow/*). AC10-a/b are self-referential
# and pass once this file itself exists — they carry no independent
# evidential weight (verification design §3).
#
# Wc-portability note (GATE:PLAN finding, applied throughout this file): BSD
# `wc -l` space-pads its output (` 3` not `3`), so every `wc -l`/`wc -c`
# comparison in this suite pipes through `tr -d ' '` per the repo convention
# at tests/test-issue-953-cycle-digest.sh:293.
#
# SIGPIPE-scan note (GATE:PLAN finding): tests/test-issue-964-*.sh:137 scans
# "$PROJECT_ROOT"/tests/*.sh repo-wide for two hazard shapes — a
# `grep -[ABC] N ... | grep -q` compound pipe with no intervening `)`, and a
# bare-identifier producer piped into `grep -q`/`-m`. Every grep-into-grep in
# this file quotes its producer argument (`"$VAR"`/`'$VAR'`), so no pipe here
# is ever preceded by a bare identifier; verified by running that suite after
# this file was written (see Test AI RED report).
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

EMIT_SCRIPT="$PROJECT_ROOT/scripts/canary/emit-phase-marker.sh"
CI_WORKFLOW="$PROJECT_ROOT/.github/workflows/e2e-dummy-target.yml"
SELF_FILE="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

PASS=0; FAIL=0; TESTS=0
TMP_DIRS=()
TMP_FILES=()

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
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

# run_emit <tmpdir> <args...> — invokes the copied emitter inside <tmpdir>,
# captures stdout/stderr to separate temp files, sets EMIT_RC/EMIT_OUT/EMIT_ERR
# (the latter two are PATHS to the captured streams, not their content —
# verification design §2.0/§2.11 self-caught-defect note).
run_emit() {
  local tmp="$1"; shift
  local out err rc
  out="$(mktemp)"; err="$(mktemp)"
  TMP_FILES+=("$out" "$err")
  ( cd "$tmp" && bash scripts/canary/emit-phase-marker.sh "$@" ) >"$out" 2>"$err"
  rc=$?
  EMIT_RC="$rc"; EMIT_OUT="$out"; EMIT_ERR="$err"
}

# new_tmp_tree — mktemp -d, register for cleanup, copy the emitter into the
# narrow subtree (verification design §2.0's [MUST]: never target this repo).
new_tmp_tree() {
  local d
  d="$(mktemp -d)"
  TMP_DIRS+=("$d")
  mkdir -p "$d/scripts/canary"
  cp "$EMIT_SCRIPT" "$d/scripts/canary/emit-phase-marker.sh"
  chmod +x "$d/scripts/canary/emit-phase-marker.sh"
  printf '%s' "$d"
}

cleanup() {
  local d f
  for d in "${TMP_DIRS[@]:-}"; do [ -n "$d" ] && rm -rf "$d" 2>/dev/null; done
  for f in "${TMP_FILES[@]:-}"; do [ -n "$f" ] && rm -f "$f" 2>/dev/null; done
}
trap cleanup EXIT

# =============================================================================
echo "=== AC1 (RED discriminator) — script exists, executable, tracked mode 100755 ==="
# =============================================================================

assert_true "AC1-a: scripts/canary/emit-phase-marker.sh exists and is executable" \
  "[ -x '$EMIT_SCRIPT' ]"

AC1_MODE="$(git -C "$PROJECT_ROOT" ls-files -s scripts/canary/emit-phase-marker.sh 2>/dev/null | cut -d' ' -f1)"
assert_true "AC1-b: tracked git index mode is 100755 (index property, not a filesystem one)" \
  "[ \"\$AC1_MODE\" = '100755' ]"

# =============================================================================
echo ""
echo "=== AC9 (guard, vacuous at HEAD) — .autoflow/*.jsonl already gitignored ==="
# =============================================================================

assert_true "AC9-a: .autoflow/issue-35-phases.jsonl is gitignored (.gitignore:6 .autoflow/*)" \
  "git check-ignore -q .autoflow/issue-35-phases.jsonl"
assert_false "AC9-b: contrast control — a tracked docs/ file is NOT gitignored" "git check-ignore -q docs/autoflow-guide.md"

# =============================================================================
echo ""
echo "=== E3 (RED discriminator) — CI self-registration (e2e-dummy-target.yml) ==="
# =============================================================================

if [ -f "$CI_WORKFLOW" ]; then
  assert_true "E3-CI-a: e2e-dummy-target.yml references test-issue-35-phase-marker.sh" \
    "grep -q 'test-issue-35-phase-marker' '$CI_WORKFLOW'"
  assert_true "E3-CI-b: reference appears in a 'paths:' trigger block" \
    "ctx=\$(grep -B30 'test-issue-35-phase-marker' '$CI_WORKFLOW'); printf '%s\n' \"\$ctx\" | grep -q '^ *paths:'"
  assert_true "E3-CI-c: a 'run: bash tests/test-issue-35-phase-marker.sh' step exists" \
    "ctx=\$(grep -A2 'test-issue-35-phase-marker' '$CI_WORKFLOW'); printf '%s\n' \"\$ctx\" | grep -q 'run: bash tests/test-issue-35-phase-marker.sh'"
else
  assert_true "E3-CI-a: $CI_WORKFLOW exists" "false"
  echo "  SKIP: E3-CI-b/c (workflow file missing)"
  TESTS=$((TESTS + 2))
fi

# =============================================================================
# Everything below requires the emitter to exist and be invocable. Per
# verification design §4: absence must register as a hard FAIL, not a
# silent SKIP — the guard below preserves the RED signal via one explicit
# assert_true "false" fallback plus a manual TESTS bump for the arms that
# cannot run (precedent: tests/test-issue-953-cycle-digest.sh:477-479).
# =============================================================================

if [ -x "$EMIT_SCRIPT" ]; then

  # ===========================================================================
  echo ""
  echo "=== AC2 (happy path) — one object per invocation, at the specified path ==="
  # ===========================================================================

  AC2_TMP="$(new_tmp_tree)"
  mkdir -p "$AC2_TMP/.autoflow"
  : > "$AC2_TMP/.autoflow/issue-35-phases.jsonl"
  AC2_TARGET="$AC2_TMP/.autoflow/issue-35-phases.jsonl"

  run_emit "$AC2_TMP" --issue 35 --cycle 1 --phase RED --event enter
  AC2_RC="$EMIT_RC"; AC2_OUT="$EMIT_OUT"

  assert_true "AC2-a: exit 0 on a valid invocation" "[ '$AC2_RC' -eq 0 ]"
  assert_true "AC2-b: .autoflow/issue-35-phases.jsonl exists after the run" "[ -f '$AC2_TARGET' ]"
  AC2_LINES_AFTER="$(wc -l < "$AC2_TARGET" | tr -d ' ')"
  assert_true "AC2-c: line count delta is exactly 1 (empty -> $AC2_LINES_AFTER)" "[ '$AC2_LINES_AFTER' = '1' ]"

  run_emit "$AC2_TMP" --issue 36 --cycle 1 --phase RED --event enter
  assert_true "AC2-d: second invocation with a different --issue exits 0" "[ '$EMIT_RC' -eq 0 ]"
  assert_true "AC2-d: .autoflow/issue-36-phases.jsonl is created (per-issue file)" \
    "[ -f '$AC2_TMP/.autoflow/issue-36-phases.jsonl' ]"
  assert_true "AC2-d: issue-35's file is unaffected by the issue-36 invocation" \
    "[ \"\$(wc -l < '$AC2_TARGET' | tr -d ' ')\" = '$AC2_LINES_AFTER' ]"

  assert_true "AC2-e: filename/field divergence asserted as one block (bare-digit filename, #-prefixed field)" \
    "[ -f '$AC2_TARGET' ] && printf '%s' \"\$(sed -n '1p' '$AC2_TARGET')\" | jq -e '.issue == \"#35\"' >/dev/null 2>&1"

  # ===========================================================================
  echo ""
  echo "=== AC3 (RED discriminator) — record fields ==="
  # ===========================================================================

  AC3_LINE1="$(sed -n '1p' "$AC2_TARGET")"

  assert_true "AC3-a: all six keys present" \
    "printf '%s' \"\$AC3_LINE1\" | jq -e 'has(\"issue\") and has(\"cycle\") and has(\"phase\") and has(\"event\") and has(\"ts\") and has(\"schema_version\")' >/dev/null 2>&1"
  assert_true "AC3-b: no extra keys (closed six-key set)" \
    "printf '%s' \"\$AC3_LINE1\" | jq -e '(keys_unsorted|sort) == [\"cycle\",\"event\",\"issue\",\"phase\",\"schema_version\",\"ts\"]' >/dev/null 2>&1"
  assert_true "AC3-c: phase round-trips from argv (== RED)" \
    "printf '%s' \"\$AC3_LINE1\" | jq -e '.phase == \"RED\"' >/dev/null 2>&1"
  assert_true "AC3-d: event round-trips from argv (== enter)" \
    "printf '%s' \"\$AC3_LINE1\" | jq -e '.event == \"enter\"' >/dev/null 2>&1"
  assert_true "AC3-e: issue is the JSON string \"#35\"; cycle is the JSON number 1" \
    "printf '%s' \"\$AC3_LINE1\" | jq -e '(.issue|type)==\"string\" and .issue==\"#35\" and (.cycle|type)==\"number\" and .cycle==1' >/dev/null 2>&1"

  AC3_F_REGEX='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(Z|[+-][0-9]{2}:?[0-9]{2})$'
  assert_true "AC3-f: ts matches ISO-8601 with timezone" \
    "printf '%s' \"\$AC3_LINE1\" | jq -e --arg re \"\$AC3_F_REGEX\" '.ts|test(\$re)' >/dev/null 2>&1"

  assert_true "AC3-g: schema_version is the JSON number 1" \
    "printf '%s' \"\$AC3_LINE1\" | jq -e '(.schema_version|type)==\"number\" and .schema_version==1' >/dev/null 2>&1"

  # Source-shape guards on the emitter file itself (single ts producer).
  assert_true "AC3-f2: the date invocation carries -u" \
    "grep -qE 'date[[:space:]]+-u' '$EMIT_SCRIPT'"
  AC3_F3_REGEX='%z|--iso-8601'
  assert_false "AC3-f3: script contains neither %z nor --iso-8601 (whole file, comments included)" \
    "grep -qE \"\$AC3_F3_REGEX\" '$EMIT_SCRIPT'"
  AC3_F5A_LITERAL='TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"'
  assert_true "AC3-f5a: single ts producer present, exact byte spelling (unconditional, no override wrapper)" \
    "grep -qF \"\$AC3_F5A_LITERAL\" '$EMIT_SCRIPT'"
  AC3_F5B_REGEX='PHASE_MARKER_TS'
  AC3_STRIPPED="$(grep -vE '^[[:space:]]*#' "$EMIT_SCRIPT" 2>/dev/null || true)"
  assert_false "AC3-f5b: no executable (non-comment) line consults PHASE_MARKER_TS" \
    "printf '%s\n' \"\$AC3_STRIPPED\" | grep -qE \"\$AC3_F5B_REGEX\""

  # AC3-f4 — bounded [start, end] window around the invocation.
  AC3F4_START="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  run_emit "$AC2_TMP" --issue 35 --cycle 1 --phase 'GATE:PLAN' --event enter
  AC3F4_END="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  AC3F4_RC="$EMIT_RC"
  AC3F4_TS="$(sed -n '2p' "$AC2_TARGET" 2>/dev/null | jq -r '.ts' 2>/dev/null)"
  assert_true "AC3-f4: emitted ts lies within the [start,end] wall-clock window around the invocation" \
    "[ '$AC3F4_RC' -eq 0 ] && [ -n \"\$AC3F4_TS\" ] && [[ ! \"\$AC3F4_TS\" < '$AC3F4_START' ]] && [[ ! \"\$AC3F4_TS\" > '$AC3F4_END' ]]"

  # AC3-h / AC3-h2 — whole-line shape + del(.ts) byte compare, dedicated clean tree.
  AC3H_TMP="$(new_tmp_tree)"
  mkdir -p "$AC3H_TMP/.autoflow"
  run_emit "$AC3H_TMP" --issue 35 --cycle 1 --phase 'GATE:PLAN' --event enter
  AC3H_LINE="$(sed -n '1p' "$AC3H_TMP/.autoflow/issue-35-phases.jsonl" 2>/dev/null)"
  AC3_H_REGEX='^\{"schema_version":1,"issue":"#35","cycle":1,"phase":"GATE:PLAN","event":"enter","ts":"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z"\}$'
  assert_true "AC3-h: whole-line shape (key order, types, closed brace) on the sole production path" \
    "printf '%s' \"\$AC3H_LINE\" | grep -qE \"\$AC3_H_REGEX\""
  AC3_H2_EXPECTED='{"schema_version":1,"issue":"#35","cycle":1,"phase":"GATE:PLAN","event":"enter"}'
  assert_true "AC3-h2: del(.ts) byte-exact compare against the whole-record literal" \
    "[ \"\$(printf '%s' \"\$AC3H_LINE\" | jq -c 'del(.ts)' 2>/dev/null)\" = \"\$AC3_H2_EXPECTED\" ]"

  # ===========================================================================
  echo ""
  echo "=== AC4 (JSONL validity) — jq -c . per line, every line an object ==="
  # ===========================================================================

  AC4_JQB='[inputs] | map(type == "object") | all'
  assert_true "AC4-a: whole-file jq -c parse succeeds (no malformed line)" \
    "jq -c . '$AC2_TARGET' >/dev/null 2>&1"
  assert_true "AC4-b: every line parses as a JSON object" \
    "jq -e -n \"\$AC4_JQB\" '$AC2_TARGET' >/dev/null 2>&1"

  # ===========================================================================
  echo ""
  echo "=== AC5 (argument validation) — missing/empty/non-canonical required args ==="
  # ===========================================================================

  V_TMP="$(new_tmp_tree)"
  mkdir -p "$V_TMP/.autoflow"
  V_SEED_LINE='{"seed":"AC5-marker-untouched"}'
  V_TARGET="$V_TMP/.autoflow/issue-35-phases.jsonl"
  printf '%s\n' "$V_SEED_LINE" > "$V_TARGET"

  check_v_arm() {
    local label="$1"; shift
    run_emit "$V_TMP" "$@"
    assert_true "$label: exit code non-zero" "[ '$EMIT_RC' -ne 0 ]"
    assert_true "$label: stderr non-empty" "[ -s '$EMIT_ERR' ]"
    assert_true "$label: stdout empty (a failed run must not emit an anchor)" "[ ! -s '$EMIT_OUT' ]"
    assert_true "$label: target unchanged (appends nothing, does not truncate)" \
      "[ \"\$(cat '$V_TARGET')\" = \"\$V_SEED_LINE\" ]"
  }

  check_v_arm "AC5-V1 (no arguments at all)"
  check_v_arm "AC5-V2 (--issue omitted)" --cycle 1 --phase RED --event enter
  check_v_arm "AC5-V3 (--issue empty)" --issue "" --cycle 1 --phase RED --event enter
  check_v_arm "AC5-V4 (--cycle omitted)" --issue 35 --phase RED --event enter
  check_v_arm "AC5-V5 (--cycle empty)" --issue 35 --cycle "" --phase RED --event enter
  check_v_arm "AC5-V6 (--phase omitted)" --issue 35 --cycle 1 --event enter
  check_v_arm "AC5-V7 (--phase empty)" --issue 35 --cycle 1 --phase "" --event enter
  check_v_arm "AC5-V8 (--event omitted)" --issue 35 --cycle 1 --phase RED
  check_v_arm "AC5-V9 (--event empty)" --issue 35 --cycle 1 --phase RED --event ""
  check_v_arm "AC5-V10 (trailing flag with no value)" --issue 35 --cycle 1 --phase RED --event
  assert_true "AC5-V10-msg: stderr carries the script's own name token (not a bash unbound-variable trap)" \
    "grep -q 'emit-phase-marker' '$EMIT_ERR'"
  check_v_arm "AC5-V14 (unknown flag, DCR-I)" --issue 35 --cycle 1 --phase RED --event enter --extra x
  check_v_arm "AC5-V14b (bare positional token)" --issue 35 --cycle 1 --phase RED --event enter stray
  check_v_arm "AC5-V15b (--cycle 007, silent-normalization defect)" --issue 35 --cycle 007 --phase RED --event enter
  check_v_arm "AC5-V16b (--cycle 0)" --issue 35 --cycle 0 --phase RED --event enter

  # V15/V16 target a DIFFERENT --issue value than the seeded tree, so the
  # post-condition is non-existence of that issue's file, not a byte compare.
  run_emit "$V_TMP" --issue 007 --cycle 1 --phase RED --event enter
  assert_true "AC5-V15: exit code non-zero (--issue 007, non-canonical identity)" "[ '$EMIT_RC' -ne 0 ]"
  assert_true "AC5-V15: stderr non-empty" "[ -s '$EMIT_ERR' ]"
  assert_true "AC5-V15: stdout empty" "[ ! -s '$EMIT_OUT' ]"
  assert_true "AC5-V15: no issue-007-phases.jsonl is created" "[ ! -f '$V_TMP/.autoflow/issue-007-phases.jsonl' ]"
  assert_true "AC5-V15-msg: stderr names the offending --issue flag" "grep -q -- '--issue' '$EMIT_ERR'"

  run_emit "$V_TMP" --issue 0 --cycle 1 --phase RED --event enter
  assert_true "AC5-V16: exit code non-zero (--issue 0)" "[ '$EMIT_RC' -ne 0 ]"
  assert_true "AC5-V16: stderr non-empty" "[ -s '$EMIT_ERR' ]"
  assert_true "AC5-V16: stdout empty" "[ ! -s '$EMIT_OUT' ]"
  assert_true "AC5-V16: no issue-0-phases.jsonl is created" "[ ! -f '$V_TMP/.autoflow/issue-0-phases.jsonl' ]"

  # Absent-file variant: a temp tree with no .autoflow/ at all.
  ABS_TMP="$(new_tmp_tree)"
  run_emit "$ABS_TMP"
  assert_true "AC5-abs-V1: exit non-zero (no args, no pre-existing .autoflow/)" "[ '$EMIT_RC' -ne 0 ]"
  assert_true "AC5-abs-V1: .autoflow/ is not created by a failing run" "[ ! -d '$ABS_TMP/.autoflow' ]"
  assert_true "AC5-abs-V1: target file does not exist" "[ ! -f '$ABS_TMP/.autoflow/issue-35-phases.jsonl' ]"

  run_emit "$ABS_TMP" --issue "" --cycle 1 --phase RED --event enter
  assert_true "AC5-abs-V3: exit non-zero (--issue empty, no pre-existing .autoflow/)" "[ '$EMIT_RC' -ne 0 ]"
  assert_true "AC5-abs-V3: .autoflow/ is not created by a failing run" "[ ! -d '$ABS_TMP/.autoflow' ]"

  # ===========================================================================
  echo ""
  echo "=== AC6 (argument validation) — unrecognized --event ==="
  # ===========================================================================

  check_v_arm "AC6-V11 (--event start, plain unrecognized token)" --issue 35 --cycle 1 --phase RED --event start
  check_v_arm "AC6-V12 (--event enter,exit, forbids substring/glob match)" --issue 35 --cycle 1 --phase RED --event "enter,exit"
  check_v_arm "AC6-V13 (--event ENTER, case sensitivity)" --issue 35 --cycle 1 --phase RED --event ENTER

  run_emit "$V_TMP" --issue 35 --cycle 1 --phase RED --event exit
  assert_true "AC6-positive-control: --event exit exits 0" "[ '$EMIT_RC' -eq 0 ]"
  assert_true "AC6-positive-control: emitted event field == exit" \
    "printf '%s' \"\$(sed -n '\$p' '$V_TARGET')\" | jq -e '.event == \"exit\"' >/dev/null 2>&1"

  # ===========================================================================
  echo ""
  echo "=== AC7 (append, not truncate) — repeated invocation preserves prior bytes ==="
  # ===========================================================================

  AC7_TMP="$(new_tmp_tree)"
  mkdir -p "$AC7_TMP/.autoflow"
  AC7_TARGET="$AC7_TMP/.autoflow/issue-35-phases.jsonl"
  AC7_SEED1='{"seed":"AC7-line-one"}'
  AC7_SEED2='{"seed":"AC7-line-two"}'
  printf '%s\n%s\n' "$AC7_SEED1" "$AC7_SEED2" > "$AC7_TARGET"

  run_emit "$AC7_TMP" --issue 35 --cycle 1 --phase RED --event enter
  AC7_RC1="$EMIT_RC"; AC7_ANCHOR1="$(cat "$EMIT_OUT" 2>/dev/null)"
  AC7_LINES1="$(wc -l < "$AC7_TARGET" | tr -d ' ')"
  run_emit "$AC7_TMP" --issue 35 --cycle 1 --phase RED --event exit
  AC7_RC2="$EMIT_RC"; AC7_ANCHOR2="$(cat "$EMIT_OUT" 2>/dev/null)"
  AC7_LINES2="$(wc -l < "$AC7_TARGET" | tr -d ' ')"

  assert_true "AC7-a: both successive invocations exit 0" "[ '$AC7_RC1' -eq 0 ] && [ '$AC7_RC2' -eq 0 ]"
  assert_true "AC7-b: file has exactly 4 lines (2 seed + 2 appended)" "[ \"\$(wc -l < '$AC7_TARGET' | tr -d ' ')\" = '4' ]"
  assert_true "AC7-c: seed lines 1-2 preserved byte-for-byte" \
    "[ \"\$(sed -n '1p' '$AC7_TARGET')\" = \"\$AC7_SEED1\" ] && [ \"\$(sed -n '2p' '$AC7_TARGET')\" = \"\$AC7_SEED2\" ]"
  assert_true "AC7-d: lines 3-4 carry event enter/exit in append order" \
    "[ \"\$(sed -n '3p' '$AC7_TARGET' | jq -r '.event')\" = 'enter' ] && [ \"\$(sed -n '4p' '$AC7_TARGET' | jq -r '.event')\" = 'exit' ]"

  AC7_E1_REGEX='[^>&]>[[:space:]]*"\$TARGET"'
  assert_false "AC7-e1: no truncating single-> redirect targeting \$TARGET anywhere in the file" \
    "grep -qE \"\$AC7_E1_REGEX\" '$EMIT_SCRIPT'"
  assert_true "AC7-e2: the append (>> \"\$TARGET\") is locatable by token" \
    "grep -qF '>> \"\$TARGET\"' '$EMIT_SCRIPT'"

  # ===========================================================================
  echo ""
  echo "=== AC8 (target directory auto-creation) — created if absent, mkdir before append ==="
  # ===========================================================================

  AC8_TMP="$(new_tmp_tree)"
  assert_true "AC8-precondition: no .autoflow/ directory before the run" "[ ! -d '$AC8_TMP/.autoflow' ]"

  run_emit "$AC8_TMP" --issue 35 --cycle 1 --phase RED --event enter
  AC8_RC="$EMIT_RC"
  AC8_TARGET="$AC8_TMP/.autoflow/issue-35-phases.jsonl"
  assert_true "AC8-a: exit 0" "[ '$AC8_RC' -eq 0 ]"
  assert_true "AC8-b: .autoflow/issue-35-phases.jsonl exists" "[ -f '$AC8_TARGET' ]"
  assert_true "AC8-c: target file has exactly 1 line" "[ \"\$(wc -l < '$AC8_TARGET' | tr -d ' ')\" = '1' ]"

  AC8_MKDIR_LINE="$(grep -n 'mkdir[[:space:]]\+-p.*dirname.*TARGET' "$EMIT_SCRIPT" 2>/dev/null | head -1 | cut -d: -f1)"
  AC8_APPEND_LINE="$(grep -n '>>[[:space:]]*"\$TARGET"' "$EMIT_SCRIPT" 2>/dev/null | head -1 | cut -d: -f1)"
  assert_true "AC8-d1: a mkdir -p targeting the TARGET parent is locatable by token" "[ -n \"\$AC8_MKDIR_LINE\" ]"
  assert_true "AC8-d2: the >> \"\$TARGET\" append line is locatable by token" "[ -n \"\$AC8_APPEND_LINE\" ]"
  assert_true "AC8-d3: the mkdir line precedes the append line (creation before write)" \
    "[ -n \"\$AC8_MKDIR_LINE\" ] && [ -n \"\$AC8_APPEND_LINE\" ] && [ \"\$AC8_MKDIR_LINE\" -lt \"\$AC8_APPEND_LINE\" ]"

  # ===========================================================================
  echo ""
  echo "=== AC11 (stdout anchor contract) — path:line only, never the record body ==="
  # ===========================================================================

  assert_true "AC11-a: stdout is exactly one line" "[ \"\$(wc -l < '$AC2_OUT' | tr -d ' ')\" = '1' ]"
  AC11_B_REGEX='^\.autoflow/issue-35-phases\.jsonl:[0-9]+$'
  assert_true "AC11-b: stdout matches the repo-relative path:line anchor form" \
    "grep -qE \"\$AC11_B_REGEX\" '$AC2_OUT'"
  assert_true "AC11-c: the stdout counter equals the post-append total line count for each invocation (computed via wc -l, not a hardcoded literal)" \
    "[ \"\${AC7_ANCHOR1##*:}\" = \"\$AC7_LINES1\" ] && [ \"\${AC7_ANCHOR2##*:}\" = \"\$AC7_LINES2\" ]"
  AC11_D_REGEX='schema_version|"phase"|\{'
  assert_false "AC11-d: stdout contains none of the record body's tokens" \
    "grep -qE \"\$AC11_D_REGEX\" '$AC2_OUT'"
  assert_true "AC11-e: stdout byte length is under a coarse ceiling (120 bytes)" \
    "[ \"\$(wc -c < '$AC2_OUT' | tr -d ' ')\" -lt 120 ]"

  # ===========================================================================
  echo ""
  echo "=== E1 (script leg) — inline SPDX header, first 3 lines ==="
  # ===========================================================================

  assert_true "E1-script: emitter carries SPDX-FileCopyrightText in its first 3 lines" \
    "head -3 '$EMIT_SCRIPT' | grep -q 'SPDX-FileCopyrightText'"
  assert_true "E1-script: emitter carries SPDX-License-Identifier in its first 3 lines" \
    "head -3 '$EMIT_SCRIPT' | grep -q 'SPDX-License-Identifier'"

else
  assert_true "AC1-a (guard fallback): scripts/canary/emit-phase-marker.sh exists and is executable" "false"
  echo "  SKIP: AC2, AC3, AC4, AC5, AC6, AC7, AC8, AC11, E1-script (emitter absent pre-implementation)"
  TESTS=$((TESTS + 128))
fi

# =============================================================================
echo ""
echo "=== AC10 (self-referential, low weight) — this suite's own coverage shape ==="
# =============================================================================

assert_true "AC10-a: this suite file is tracked and carries an inline SPDX header" \
  "head -3 '$SELF_FILE' | grep -q 'SPDX-FileCopyrightText' && head -3 '$SELF_FILE' | grep -q 'SPDX-License-Identifier'"
assert_true "AC10-b: suite contains a banner section for happy path, argument validation, append-not-truncate, and JSONL validity" \
  "grep -qF 'happy path' '$SELF_FILE' && grep -qF 'argument validation' '$SELF_FILE' && grep -qF 'append, not truncate' '$SELF_FILE' && grep -qF 'JSONL validity' '$SELF_FILE'"

# =============================================================================
echo ""
echo "Results: $PASS/$TESTS passed, $FAIL failed"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
