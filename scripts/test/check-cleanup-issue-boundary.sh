#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# scripts/test/check-cleanup-issue-boundary.sh
#
# Regression test for scripts/cleanup/cleanup-issue.sh — ARCHIVE semantics
# (issue #978). The mechanism no longer DELETES a resolved issue's
# .autoflow/issue-<N>.*/-* files; it MOVES them to
# $AUTOFLOW_ARCHIVE_ROOT/<repo-key>/issue-<N>-<date>/. This suite guards:
#
#   AC-1 — move (not delete), set integrity (count + byte content), the
#          number-boundary guard (12 must not match 123/120), and the
#          destination-exists conflict-suffix (non-destructive re-seed case).
#   AC-3 — repo-tree non-interference (git status --porcelain byte-identical
#          before/after; a co-resident LIVE issue (never passed to the
#          wrapper) still reads `active` to the hook after an unrelated
#          issue's archive); and the exit-65 refuse guard when
#          AUTOFLOW_ARCHIVE_ROOT points inside the repo tree.
#   AC-7 — this file itself, re-targeted from delete-assertion to
#          archive-assertion (same file guards AC-1/AC-3/AC-7 — no separate
#          harness; superset-of-AC-1 per the verification design).
#
# All archive writes in this suite go under `mktemp -d` roots — NEVER the
# operator's real $HOME/.autoflow — so this suite is safe to run repeatedly
# without home-directory pollution.
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel)"
AF="$ROOT/.autoflow"
CLEAN="$ROOT/scripts/cleanup/cleanup-issue.sh"
HOOK="$ROOT/.claude/hooks/check-autoflow-gate.sh"

PASS=0; FAIL=0; TESTS=0

assert_true() {
  local desc="$1" condition="$2"
  TESTS=$((TESTS + 1))
  if eval "$condition"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  TESTS=$((TESTS + 1))
  if [ "$actual" = "$expected" ]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected '$expected', got '$actual')"
    FAIL=$((FAIL + 1))
  fi
}

# cmp_content <file> <expected-content> — byte-identical check without
# keeping a persistent backup copy of the seed (inode/mtime-agnostic per the
# verification design — content + count only, tolerant of a cross-filesystem
# mv's copy+unlink semantics).
cmp_content() {
  local f="$1" expected="$2" tmp rc
  tmp="$(mktemp)"
  printf '%s' "$expected" > "$tmp"
  cmp -s "$f" "$tmp"
  rc=$?
  rm -f "$tmp"
  return $rc
}

# ---------------------------------------------------------------------------
# Test ids — high, unlikely-to-collide numbers (existing convention).
# ---------------------------------------------------------------------------
A=9990012      # AC-1/AC-7 archive target
B=99900123     # prefix-collision sibling (must survive, number-boundary)
C=99900120     # prefix-collision sibling (must survive, number-boundary)
D=99900199     # AC-3 archive target (repo-tree non-interference)
M=99900211     # AC-3 co-resident LIVE issue — never passed to the wrapper
E=99900222     # AC-3 hardening: exit-65 inside-repo-root guard target
F=99900233     # AUDIT r1: symlink-bypass guard target

ARCHIVE_ROOT_1="$(mktemp -d)"   # AC-1/AC-7 phase
ARCHIVE_ROOT_3="$(mktemp -d)"   # AC-3 non-interference phase
INSIDE_ROOT="$AF/inside-guard-archive-test"   # deliberately INSIDE $ROOT (and
                                               # still under gitignored
                                               # .autoflow/, so porcelain stays
                                               # clean regardless of the
                                               # guard's pass/fail outcome)
INSIDE_REL=".autoflow/rel-guard-archive-test"  # RELATIVE value that resolves
                                               # inside $ROOT when invoked from
                                               # $ROOT — pins the :97
                                               # normalization leg (E12); same
                                               # gitignored-isolation rationale
SYMLINK_ROOT="$(mktemp -d)"                    # AUDIT r1: holds the outside-tree
                                               # symlink whose TARGET resolves
                                               # inside the repo tree
EVIL_TARGET="$AF/evil-archive"                 # symlink target INSIDE the tree
                                               # (under gitignored .autoflow/,
                                               # so porcelain stays clean
                                               # whichever way the guard goes)
EVIL_LINK="$SYMLINK_ROOT/evil-link"            # textually outside-tree path
                                               # that physically resolves inside

teardown() {
  find "$AF" -maxdepth 1 -type f \
    \( -name "issue-${A}*" -o -name "issue-${B}*" -o -name "issue-${C}*" \
       -o -name "issue-${D}*" -o -name "issue-${M}*" -o -name "issue-${E}*" \
       -o -name "issue-${F}*" \) \
    -delete 2>/dev/null || true
  rm -rf "$ARCHIVE_ROOT_1" "$ARCHIVE_ROOT_3" "$INSIDE_ROOT" "$AF/rel-guard-archive-test" \
         "$SYMLINK_ROOT" "$EVIL_TARGET" 2>/dev/null || true
}
trap teardown EXIT

mkdir -p "$AF"

# ---------------------------------------------------------------------------
echo "=== AC-1 / AC-7: archive move — integrity + number-boundary ==="
# ---------------------------------------------------------------------------
A_JSON_V1="issue-${A} state seed v1"
A_LEDGER_V1="issue-${A} ledger seed v1"
printf '%s' "$A_JSON_V1"   > "$AF/issue-${A}.json"
printf '%s' "$A_LEDGER_V1" > "$AF/issue-${A}-ledger.md"
printf '%s' "issue-${B} state seed"  > "$AF/issue-${B}.json"
printf '%s' "issue-${B} ledger seed" > "$AF/issue-${B}-ledger.md"
printf '%s' "issue-${C} state seed"  > "$AF/issue-${C}.json"

AUTOFLOW_ARCHIVE_ROOT="$ARCHIVE_ROOT_1" "$CLEAN" "$A" >/dev/null

assert_true "AC-1: target issue-${A} files gone from live .autoflow/" \
  "[ ! -e '$AF/issue-${A}.json' ] && [ ! -e '$AF/issue-${A}-ledger.md' ]"

DEST1="$(find "$ARCHIVE_ROOT_1" -mindepth 2 -maxdepth 2 -type d -name "issue-${A}-*" 2>/dev/null | sort | head -1)"
assert_true "AC-1: archive landing dir exists under \$AUTOFLOW_ARCHIVE_ROOT/<repo-key>/issue-${A}-*/" \
  "[ -n '$DEST1' ] && [ -d '$DEST1' ]"

if [ -n "$DEST1" ]; then
  COUNT1="$(find "$DEST1" -maxdepth 1 -type f | grep -c .)"
  assert_eq "AC-1: archived file count for issue-${A} == 2 (state + ledger)" "2" "$COUNT1"
  assert_true "AC-1: archived issue-${A}.json is byte-identical to the seed" \
    "cmp_content '$DEST1/issue-${A}.json' \"\$A_JSON_V1\""
  assert_true "AC-1: archived issue-${A}-ledger.md is byte-identical to the seed" \
    "cmp_content '$DEST1/issue-${A}-ledger.md' \"\$A_LEDGER_V1\""
else
  echo "  SKIP: archived-content checks (no landing dir found)"
  TESTS=$((TESTS + 2))
fi

assert_true "AC-1/number-boundary: prefix-collision sibling issue-${B} still in live .autoflow/" \
  "[ -e '$AF/issue-${B}.json' ] && [ -e '$AF/issue-${B}-ledger.md' ]"
assert_true "AC-1/number-boundary: prefix-collision sibling issue-${C} still in live .autoflow/" \
  "[ -e '$AF/issue-${C}.json' ]"

# ---------------------------------------------------------------------------
echo ""
echo "=== AC-1: conflict-suffix (re-seed between runs, NOT a plain double-run) ==="
# ---------------------------------------------------------------------------
# A plain double `cleanup A` does NOT reproduce a conflict: run 1 already
# moved issue-A's files out of .autoflow/, so run 2 finds an empty match set
# and creates no second dir (verified against cleanup-issue.sh:59-62 — an
# empty `matches` is a no-op, "already clean", never a suffix). The correct
# method simulates an issue reopened+reclosed the same day: RE-SEED issue-A's
# live files, then run cleanup again.
A_JSON_V2="issue-${A} state seed v2 (re-seeded)"
A_LEDGER_V2="issue-${A} ledger seed v2 (re-seeded)"
printf '%s' "$A_JSON_V2"   > "$AF/issue-${A}.json"
printf '%s' "$A_LEDGER_V2" > "$AF/issue-${A}-ledger.md"

AUTOFLOW_ARCHIVE_ROOT="$ARCHIVE_ROOT_1" "$CLEAN" "$A" >/dev/null

DEST2="$(find "$ARCHIVE_ROOT_1" -mindepth 2 -maxdepth 2 -type d -name "issue-${A}-*" 2>/dev/null | sort | sed -n '2p')"
assert_true "AC-1: re-seed-between-runs produces a SECOND (suffixed) archive dir" \
  "[ -n '$DEST2' ] && [ -d '$DEST2' ]"

if [ -n "$DEST1" ] && [ -d "$DEST1" ]; then
  assert_true "AC-1: the FIRST archive dir is preserved unchanged (not overwritten)" \
    "cmp_content '$DEST1/issue-${A}.json' \"\$A_JSON_V1\""
fi
if [ -n "$DEST2" ]; then
  assert_true "AC-1: the SECOND archive dir holds the re-seeded (v2) content" \
    "cmp_content '$DEST2/issue-${A}.json' \"\$A_JSON_V2\""
fi

# ---------------------------------------------------------------------------
echo ""
echo "=== AC-3: repo-tree non-interference ==="
# ---------------------------------------------------------------------------
PORCELAIN_BEFORE="$(cd "$ROOT" && git status --porcelain)"
GITIGNORE_MD5_BEFORE="$(md5sum "$ROOT/.gitignore" 2>/dev/null || md5 -q "$ROOT/.gitignore" 2>/dev/null)"

printf '%s' "issue-${D} state seed"  > "$AF/issue-${D}.json"
printf '%s' "issue-${D} ledger seed" > "$AF/issue-${D}-ledger.md"

# M is a schema-valid, ACTIVE state file that is NEVER passed to the
# wrapper — it must be unaffected by an unrelated issue's archive move, and
# the hook must still read it as active afterward (co-resident live-issue
# oracle; the hook's scan is flat/non-recursive over "$AUTOFLOW_DIR"/*.json
# and the archive destination sits outside $AUTOFLOW_DIR entirely).
M_JSON='{
  "active": true,
  "issue": "#'"${M}"'",
  "title": "AC-3 co-resident live-issue oracle (check-cleanup-issue-boundary.sh)",
  "date": "2026-07-09",
  "cycle": 1,
  "mode": "new-issue",
  "phase": "in-progress",
  "phases": {
    "gate_hypothesis_structure": { "evaluator": "", "scores": {} },
    "gate_hypothesis_cause":     { "evaluator": "", "scores": {}, "verdict": "pending" },
    "gate_plan":                 { "evaluator": "", "scores": {} },
    "audit":                     { "evaluator": "", "scores": {} },
    "gate_quality":              { "evaluator": "", "scores": {} }
  }
}'
printf '%s' "$M_JSON" > "$AF/issue-${M}.json"

AUTOFLOW_ARCHIVE_ROOT="$ARCHIVE_ROOT_3" "$CLEAN" "$D" >/dev/null

PORCELAIN_AFTER="$(cd "$ROOT" && git status --porcelain)"
GITIGNORE_MD5_AFTER="$(md5sum "$ROOT/.gitignore" 2>/dev/null || md5 -q "$ROOT/.gitignore" 2>/dev/null)"

assert_eq "AC-3: git status --porcelain is byte-identical before/after the archive move" \
  "$PORCELAIN_BEFORE" "$PORCELAIN_AFTER"
assert_eq "AC-3: .gitignore is byte-unchanged (md5)" \
  "$GITIGNORE_MD5_BEFORE" "$GITIGNORE_MD5_AFTER"

assert_true "AC-3: co-resident live issue-${M}.json is unchanged (never touched by issue-${D}'s archive)" \
  "cmp_content '$AF/issue-${M}.json' \"\$M_JSON\""

if [ -x "$HOOK" ] && command -v jq >/dev/null 2>&1; then
  HOOK_PAYLOAD="$(printf '{"tool_name":"Bash","tool_input":{"command":%s}}' \
    "$(printf 'git push origin issue-978-ac3-probe-branch' | jq -Rs .)")"
  printf '%s' "$HOOK_PAYLOAD" | CLAUDE_PROJECT_DIR="$ROOT" bash "$HOOK" >/dev/null 2>&1
  HOOK_EXIT=$?
  assert_eq "AC-3: hook still reads issue-${M} as active (git push denied, exit 2 — AUDIT/GATE:QUALITY unmet)" \
    "2" "$HOOK_EXIT"
else
  echo "  SKIP: hook-still-active oracle (hook not executable or jq missing)"
  TESTS=$((TESTS + 1))
fi

# ---------------------------------------------------------------------------
echo ""
echo "=== AC-3 hardening: exit-65 refuse when AUTOFLOW_ARCHIVE_ROOT is inside the repo tree ==="
# ---------------------------------------------------------------------------
E_JSON="issue-${E} state seed"
printf '%s' "$E_JSON" > "$AF/issue-${E}.json"

PORCELAIN_GUARD_BEFORE="$(cd "$ROOT" && git status --porcelain)"

AUTOFLOW_ARCHIVE_ROOT="$INSIDE_ROOT" "$CLEAN" "$E" >/dev/null 2>&1
GUARD_EXIT=$?

PORCELAIN_GUARD_AFTER="$(cd "$ROOT" && git status --porcelain)"

assert_eq "AC-3 guard: AUTOFLOW_ARCHIVE_ROOT inside the repo tree → exit 65" \
  "65" "$GUARD_EXIT"
assert_true "AC-3 guard: no move performed — issue-${E} files still present in live .autoflow/" \
  "cmp_content '$AF/issue-${E}.json' \"\$E_JSON\""
assert_eq "AC-3 guard: git status --porcelain unchanged around the refused attempt" \
  "$PORCELAIN_GUARD_BEFORE" "$PORCELAIN_GUARD_AFTER"

# Relative-path leg (cleanup-issue.sh:97 — GATE:PLAN E12 carried security
# finding): a RELATIVE AUTOFLOW_ARCHIVE_ROOT is normalized against $PWD
# before the inside-repo compare, so a relative value resolving inside the
# tree cannot bypass the refuse guard. Invoke from $ROOT so the relative
# value deterministically resolves to $ROOT/.autoflow/... (inside the tree,
# and under gitignored .autoflow/ so porcelain stays clean whichever way
# the guard behaves — same oracle isolation as INSIDE_ROOT above). issue-E's
# file is still live (the absolute case above was refused), so it doubles
# as this case's no-move witness.
PORCELAIN_REL_BEFORE="$(cd "$ROOT" && git status --porcelain)"

(cd "$ROOT" && AUTOFLOW_ARCHIVE_ROOT="$INSIDE_REL" "$CLEAN" "$E") >/dev/null 2>&1
REL_GUARD_EXIT=$?

PORCELAIN_REL_AFTER="$(cd "$ROOT" && git status --porcelain)"

assert_eq "AC-3 guard (relative leg): relative AUTOFLOW_ARCHIVE_ROOT resolving inside the repo tree → exit 65" \
  "65" "$REL_GUARD_EXIT"
assert_true "AC-3 guard (relative leg): no move performed — issue-${E} files still present in live .autoflow/" \
  "cmp_content '$AF/issue-${E}.json' \"\$E_JSON\""
assert_eq "AC-3 guard (relative leg): git status --porcelain unchanged around the refused attempt" \
  "$PORCELAIN_REL_BEFORE" "$PORCELAIN_REL_AFTER"

# ---------------------------------------------------------------------------
echo ""
echo "=== AUDIT r1: symlink bypass — outside-tree link resolving INSIDE the tree ==="
# ---------------------------------------------------------------------------
# AUDIT round-1 finding (Infra isolation, .autoflow/issue-978-audit.md /
# ledger E15): the exit-65 guard compares the TEXTUAL path prefix, so an
# archive root that is a symlink at an outside-tree path whose target
# resolves INSIDE the repo tree passes the compare, and mkdir/mv then write
# through the link into the tree — breaking AC-3 non-interference. The guard
# must judge the PHYSICAL resolution, not the textual prefix: exit 65 + no
# move + nothing landing inside the tree.
F_JSON="issue-${F} state seed"
printf '%s' "$F_JSON" > "$AF/issue-${F}.json"

mkdir -p "$EVIL_TARGET"                 # target INSIDE the tree (non-dangling)
ln -s "$EVIL_TARGET" "$EVIL_LINK"       # link OUTSIDE the tree → resolves inside

PORCELAIN_SYM_BEFORE="$(cd "$ROOT" && git status --porcelain)"

AUTOFLOW_ARCHIVE_ROOT="$EVIL_LINK" "$CLEAN" "$F" >/dev/null 2>&1
SYM_GUARD_EXIT=$?

PORCELAIN_SYM_AFTER="$(cd "$ROOT" && git status --porcelain)"

assert_eq "AUDIT-sym: symlinked AUTOFLOW_ARCHIVE_ROOT resolving inside the repo tree → exit 65" \
  "65" "$SYM_GUARD_EXIT"
assert_true "AUDIT-sym: no move performed — issue-${F} files still present in live .autoflow/" \
  "cmp_content '$AF/issue-${F}.json' \"\$F_JSON\""
assert_true "AUDIT-sym: nothing landed inside the repo tree through the link (target dir stays empty)" \
  "[ -z \"\$(find '$EVIL_TARGET' -mindepth 1 2>/dev/null)\" ]"
assert_eq "AUDIT-sym: git status --porcelain unchanged around the refused attempt" \
  "$PORCELAIN_SYM_BEFORE" "$PORCELAIN_SYM_AFTER"

# ---------------------------------------------------------------------------
echo ""
echo "=== AC-CI-REGISTER (guard) — suite wired into e2e-dummy-target.yml ==="
# ---------------------------------------------------------------------------
CI_WORKFLOW="$ROOT/.github/workflows/e2e-dummy-target.yml"
if [ -f "$CI_WORKFLOW" ]; then
  assert_true "AC-CI-a: e2e-dummy-target.yml references check-cleanup-issue-boundary.sh" \
    "grep -q 'check-cleanup-issue-boundary' '$CI_WORKFLOW'"
  CTX_B="$(grep -B80 'check-cleanup-issue-boundary' "$CI_WORKFLOW" | head -80)"
  assert_true "AC-CI-b: reference appears in a 'paths:' trigger block" \
    "printf '%s\n' \"\$CTX_B\" | grep -q '^ *paths:'"
  CTX_C="$(grep -A2 'check-cleanup-issue-boundary' "$CI_WORKFLOW")"
  assert_true "AC-CI-c: reference appears in a 'run:' step" \
    "printf '%s\n' \"\$CTX_C\" | grep -q 'run: bash scripts/test/check-cleanup-issue-boundary.sh'"
else
  assert_true "AC-CI-a: $CI_WORKFLOW exists" "false"
  echo "  SKIP: AC-CI-b/c (workflow file missing)"
  TESTS=$((TESTS + 2))
fi

# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Results: $PASS/$TESTS passed, $FAIL failed"
echo "=============================="

[ "$FAIL" -gt 0 ] && exit 1
exit 0
