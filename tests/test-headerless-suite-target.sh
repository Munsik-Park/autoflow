#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# ci-subject: scripts/test/select-suites.sh scripts/test/run-suites.sh scripts/test/suite-manifest.sh scripts/test/check-suite-manifest.sh setup/thin-root-layer/drift-check.sh setup/init.sh setup/manifest.json plugin/autoflow/skills/install/scripts/detect.sh plugin/autoflow/skills/install/SKILL.md docs/autoflow-guide.md .claude/agents/autoflow-tester.md plugin/autoflow/agents/autoflow-tester.md
# lane: standing
# budget-secs: SUITE_BUDGET_CEILING_SECS
# =============================================================================
# Test: a target whose tests/** holds suites that predate the header contract
#       (issue #213) — the shipped selector's BLOCK is named at re-stamp
#       verification, the runner and the phase steps have a defined path
#       through it, and the migration's end state selects normally.
# =============================================================================
# The fixture is a real stamp (setup/init.sh --target) into a git repository
# carrying three header-less suites — the shape of the reproduction target,
# which re-stamped to a `0 failed` drift-check and then BLOCKed at RED. Every
# selector / runner / detector call runs the target's INSTALLED copy, i.e. what
# the target executes after a re-stamp, except the trust legs, which run the
# source-tree oracle the install skill runs before the operator confirms.
#
# Every leg runs under a HERMETIC $CLAUDE_CONFIG_DIR with CLAUDE_PLUGIN_ROOT /
# AUTOFLOW_MARKETPLACE_ROOT unset, so D2/D4/D5/D6 SKIP and the drift-check
# verdicts below are D7's alone.
#
# Cases (AC = the issue's acceptance criteria):
#   D7-EMPTY       a stamped target with no suite -> PASS: D7, 0 enumerated
#   SEL-BLOCK-ALL  AC3: the selector BLOCKs naming EVERY header-less suite (no
#                  header, an empty header, a nested directory), emits no
#                  selection and no SELECTED / NOT-SELECTED record, and names
#                  the migration and the --all route
#   SEL-CHECK      AC3: --check-headers lists exactly the header-less suites and
#                  resolves no delta — it runs outside a git checkout and never
#                  sources the root's tests/lib/base-ref.sh
#   RUN-SEL        AC2/AC3: run-suites.sh's selection path executes nothing,
#                  exits 1 and names --all and the migration; --all runs the
#                  enumerated set
#   D7-FAIL        AC1: the installed drift-check FAILs once per header-less
#                  suite — never `0 failed` — with a HINT naming the migration
#   D7-SKIP        the selector absent beside the detector -> SKIP: D7 naming the
#                  path tried, never a PASS
#   ORACLE-TRUST   the source-tree oracle and detect.sh evaluate D7 without
#                  executing the target's selector, library or base-ref.sh
#   DET-*          AC1: detect.sh reports D7 on the SUITE_HEADER axis, never as
#                  DRIFT; synthetic oracles pin the skip and error aggregation
#   MIGRATED       the migration's end state: --check-headers exits 0, the
#                  selector narrows by the declared tokens, the runner executes
#                  exactly the selected suites, check-suite-manifest reports OK,
#                  drift-check PASS: D7 and SUITE_HEADER_STATE=pass
#   DOC-*          AC2: the two phase steps that call the selector state the
#                  BLOCK disposition, the migration section the tool messages
#                  point to exists, PREFLIGHT names D7, the install skill reads
#                  the axis, and both shipped Test AI definitions agree
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

INIT_SH="$REPO_ROOT/setup/init.sh"
DRIFT_SRC="$REPO_ROOT/setup/thin-root-layer/drift-check.sh"
DETECT_SH="$REPO_ROOT/plugin/autoflow/skills/install/scripts/detect.sh"
SKILL_MD="$REPO_ROOT/plugin/autoflow/skills/install/SKILL.md"
GUIDE="$REPO_ROOT/docs/autoflow-guide.md"
MANIFEST="$REPO_ROOT/setup/manifest.json"
MIGRATION='Adopting the contract over existing suites'

PASS=0; FAIL=0
pass()  { echo "  PASS: $1"; PASS=$((PASS + 1)); }
failc() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT INT TERM

export CLAUDE_CONFIG_DIR="$WORK/empty-config"
mkdir -p "$CLAUDE_CONFIG_DIR"
unset CLAUDE_PLUGIN_ROOT AUTOFLOW_MARKETPLACE_ROOT GITHUB_EVENT_NAME GITHUB_BASE_REF

WITNESS="$WORK/witness.log"
T="$WORK/target"

g() { git -C "$T" -c user.email=t@example.invalid -c user.name=t -c commit.gpgsign=false "$@"; }

# write_suite <repo-relative path> <header lines, may be empty> — a suite that
# records its own path in the witness log, so execution is observable.
write_suite() {
  mkdir -p "$(dirname "$T/$1")"
  { printf '#!/usr/bin/env bash\n'
    [ -n "$2" ] && printf '%s\n' "$2"
    printf 'echo "%s" >> "%s"\n' "$1" "$WITNESS"
    printf 'exit 0\n'
  } > "$T/$1"
}
witness() { [ -f "$WITNESS" ] && cat "$WITNESS"; }

# run_drift <target> [VAR=value ...] — the target's installed detector.
run_drift() {
  local t="$1"; shift
  DRIFT_OUT=$(env CLAUDE_PROJECT_DIR="$t" "$@" sh "$t/.claude/autoflow/drift-check.sh" 2>&1)
  DRIFT_RC=$?
}
has()     { grep -qF -- "$1" <<<"$DRIFT_OUT"; }
d7()      { grep -E '^(PASS|FAIL|SKIP|HINT): D7' <<<"$DRIFT_OUT" | head -n 5 | tr '\n' ' ' | cut -c1-500; }
kv()      { sed -n "s/^$2=//p" <<<"$1" | head -n 1; }
# region <file> <start-regex> <stop-regex> — the lines from start to the next stop.
region()  { awk -v s="$2" -v e="$3" '$0 ~ s { on = 1; print; next } on && $0 ~ e { exit } on { print }' "$1"; }
contains() { grep -qF -- "$2" <<<"$1"; }

echo "=== Issue #213 — a target whose suites predate the header contract ==="

mkdir -p "$T"
if ! bash "$INIT_SH" --target "$T" >/dev/null 2>&1 \
   || [ ! -f "$T/.claude/autoflow/drift-check.sh" ] || [ ! -f "$T/scripts/test/select-suites.sh" ] \
   || [ ! -f "$T/scripts/test/run-suites.sh" ] || [ ! -f "$T/tests/lib/base-ref.sh" ]; then
  failc "SETUP: the stamp into $T did not deliver drift-check.sh + select-suites.sh + run-suites.sh + tests/lib/base-ref.sh"
  echo "PASS: $PASS  FAIL: $FAIL"; exit 1
fi
SEL="$T/scripts/test/select-suites.sh"
RUN="$T/scripts/test/run-suites.sh"

# -----------------------------------------------------------------------------
echo "== D7 on a fresh stamp =="
# -----------------------------------------------------------------------------
run_drift "$T"
if grep -q '^PASS: D7: suite headers OK — 0 suite(s) enumerated' <<<"$DRIFT_OUT" && ! has "FAIL: D7"; then
  pass "D7-EMPTY: a fresh stamp (tests/lib only) PASSes D7 with 0 suites enumerated"
else
  failc "D7-EMPTY: rc=$DRIFT_RC; $(d7)"
fi

# The reproduction shape: suites that predate the contract, committed, then a
# change commit so the selection has a non-empty delta to answer for.
mkdir -p "$T/src"; echo v1 > "$T/src/app.txt"
write_suite tests/check-legacy-alpha.sh ""
write_suite tests/check-legacy-beta.sh "# ci-subject:"
write_suite tests/nested/check-legacy-gamma.sh ""
git -C "$T" init -q
g add -A && g commit -q -m base
BASE=$(g rev-parse HEAD)
echo v2 > "$T/src/app.txt"; g commit -q -am change
HEADERLESS=$'tests/check-legacy-alpha.sh\ntests/check-legacy-beta.sh\ntests/nested/check-legacy-gamma.sh'

# -----------------------------------------------------------------------------
echo "== the selector over header-less suites (AC3) =="
# -----------------------------------------------------------------------------
out=$(bash "$SEL" --base "$BASE" 2>"$WORK/sel.err"); rc=$?
err=$(cat "$WORK/sel.err")
nb=$(grep -c "^BLOCK: select-suites — tests/.* declares no usable '# ci-subject:' header" <<<"$err")
all_named=1
while IFS= read -r s; do
  grep -qF "BLOCK: select-suites — $s declares no usable" <<<"$err" || all_named=0
done <<<"$HEADERLESS"
if [ "$rc" -eq 1 ] && [ -z "$out" ] && [ "$nb" -eq 3 ] && [ "$all_named" -eq 1 ] \
   && ! grep -qE '^(NOT-)?SELECTED:' <<<"$err" \
   && contains "$err" "$MIGRATION" && contains "$err" "'run-suites.sh --all'"; then
  pass "SEL-BLOCK-ALL: exit 1 with one BLOCK per header-less suite (all 3 named, not only the first), no selection and no partial report; the message names the migration and the --all route"
else
  failc "SEL-BLOCK-ALL: rc=$rc stdout='$out' blocks=$nb all_named=$all_named; $(head -n 6 <<<"$err" | tr '\n' ' ' | cut -c1-500)"
fi

out=$(bash "$SEL" --check-headers 2>"$WORK/chk.err"); rc=$?
err=$(cat "$WORK/chk.err")
if [ "$rc" -eq 1 ] && [ "$out" = "$HEADERLESS" ] \
   && contains "$err" "3 of 3 enumerated suite(s) declare no usable '# ci-subject:' header" && contains "$err" "$MIGRATION"; then
  pass "SEL-CHECK: --check-headers exits 1 and lists exactly the three header-less suites on stdout, naming the migration"
else
  failc "SEL-CHECK: rc=$rc stdout='$(tr '\n' '|' <<<"$out")'; $(tr '\n' ' ' <<<"$err" | cut -c1-300)"
fi

# No delta is resolved: outside a git checkout, with a base-ref library that
# would leave a marker if sourced, the answer is the same list.
N="$WORK/plain"; mkdir -p "$N/tests/lib"
cp -R "$T/tests/." "$N/tests/"
printf ': > "%s/BASE_REF_SOURCED"\nresolve_base_ref() { echo HEAD; }\n' "$WORK" > "$N/tests/lib/base-ref.sh"
out=$(bash "$SEL" --check-headers --root "$N" 2>/dev/null); rc=$?
if [ "$rc" -eq 1 ] && [ "$out" = "$HEADERLESS" ] && [ ! -e "$WORK/BASE_REF_SOURCED" ]; then
  pass "SEL-CHECK-NO-DELTA: outside any git checkout --check-headers gives the same list and never sources the root's tests/lib/base-ref.sh"
else
  failc "SEL-CHECK-NO-DELTA: rc=$rc stdout='$(tr '\n' '|' <<<"$out")' marker=$([ -e "$WORK/BASE_REF_SOURCED" ] && echo SOURCED || echo absent)"
fi

# -----------------------------------------------------------------------------
echo "== the runner's selection path (AC2/AC3) =="
# -----------------------------------------------------------------------------
rm -f "$WITNESS"
out=$(bash "$RUN" --base "$BASE" 2>&1); rc=$?
if [ "$rc" -eq 1 ] && [ -z "$(witness)" ] \
   && contains "$out" "run-suites: selection failed (exit 1) — no suite executed" \
   && contains "$out" "'run-suites.sh --all' runs the whole enumerated set" \
   && contains "$out" "'select-suites.sh --check-headers'" && contains "$out" "$MIGRATION"; then
  pass "RUN-SEL: the selection path exits 1 with nothing executed, and names both routes — --all and the header migration"
else
  failc "RUN-SEL: rc=$rc witness='$(witness | tr '\n' '|')'; $(tr '\n' ' ' <<<"$out" | cut -c1-500)"
fi

out=$(bash "$RUN" --all --list 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "$HEADERLESS" ] && [ -z "$(witness)" ]; then
  out=$(bash "$RUN" --all 2>&1); rc=$?
  if [ "$rc" -eq 0 ] && [ "$(witness)" = "$HEADERLESS" ] && contains "$out" "run-suites: 3 passed, 0 failed, 0 timed out, of 3 executed"; then
    pass "RUN-ALL: --all lists and then executes all three header-less suites — the route the BLOCK names works"
  else
    failc "RUN-ALL (execute): rc=$rc witness='$(witness | tr '\n' '|')'; $(tail -n 2 <<<"$out" | tr '\n' ' ')"
  fi
else
  failc "RUN-ALL (list): rc=$rc stdout='$(tr '\n' '|' <<<"$out")'"
fi

# -----------------------------------------------------------------------------
echo "== drift-check D7 (AC1) =="
# -----------------------------------------------------------------------------
run_drift "$T"
nf=$(grep -c '^FAIL: D7 -- ' <<<"$DRIFT_OUT")
all_named=1
while IFS= read -r s; do
  has "FAIL: D7 -- $s declares no usable '# ci-subject:' header — scripts/test/select-suites.sh BLOCKs every selection until it does" || all_named=0
done <<<"$HEADERLESS"
if [ "$DRIFT_RC" -ne 0 ] && [ "$nf" -eq 3 ] && [ "$all_named" -eq 1 ] \
   && ! grep -q '^RESULT: drift-check 0 failed' <<<"$DRIFT_OUT" \
   && grep '^HINT: D7' <<<"$DRIFT_OUT" | grep -qF "$MIGRATION"; then
  pass "D7-FAIL: one FAIL: D7 per header-less suite (exit $DRIFT_RC, never '0 failed'); the HINT names the migration"
else
  failc "D7-FAIL: rc=$DRIFT_RC fails=$nf all_named=$all_named; $(d7); $(grep '^RESULT' <<<"$DRIFT_OUT")"
fi

mv "$SEL" "$WORK/select-suites.bak"
run_drift "$T"
if has "SKIP: D7 -- suite selector not found beside this script (tried: $T/.claude/autoflow/../../scripts/test/select-suites.sh" \
   && ! has "FAIL: D7" && ! has "PASS: D7"; then
  pass "D7-SKIP: the selector absent beside the detector -> SKIP: D7 naming the path tried (D1 owns the missing copy), never a PASS"
else
  failc "D7-SKIP: $(d7)"
fi
mv "$WORK/select-suites.bak" "$SEL"

# -----------------------------------------------------------------------------
echo "== TRUST: D7 evaluates the target's suites without executing target code =="
# -----------------------------------------------------------------------------
TT="$WORK/target-tampered"; cp -R "$T" "$TT"
for f in scripts/test/select-suites.sh scripts/test/suite-manifest.sh tests/lib/base-ref.sh; do
  printf '#!/usr/bin/env bash\n: > "%s/PWNED-%s"\nexit 0\n' "$WORK" "${f##*/}" > "$TT/$f"
done
out=$(env CLAUDE_PROJECT_DIR="$TT" sh "$DRIFT_SRC" 2>&1)
pwned=$(ls "$WORK" | grep -c '^PWNED-')
if [ "$pwned" -eq 0 ] && [ "$(grep -c '^FAIL: D7 -- ' <<<"$out")" -eq 3 ] \
   && grep -q '^FAIL: D1 -- content drift: scripts/test/select-suites.sh' <<<"$out"; then
  pass "ORACLE-TRUST: the source-tree oracle runs its own selector — no target script ran, D7 still names all three suites, D1 flags the tampered copy"
else
  failc "ORACLE-TRUST (oracle): markers=$pwned; $(grep -E ': D[17]' <<<"$out" | head -n 4 | tr '\n' ' ' | cut -c1-400)"
fi
out=$(env TARGET_ROOT="$TT" PLUGIN_CACHE_ROOT="$REPO_ROOT" sh "$DETECT_SH" 2>&1)
pwned=$(ls "$WORK" | grep -c '^PWNED-')
if [ "$pwned" -eq 0 ] && [ "$(kv "$out" SUITE_HEADER_STATE)" = fail ]; then
  pass "ORACLE-TRUST: detect.sh leaves no marker either and reports SUITE_HEADER_STATE=fail"
else
  failc "ORACLE-TRUST (detect): markers=$pwned; $(grep -E '^SUITE_HEADER_STATE' <<<"$out")"
fi

# -----------------------------------------------------------------------------
echo "== DET: detect.sh reports D7 on its own axis (AC1) =="
# -----------------------------------------------------------------------------
out=$(env TARGET_ROOT="$T" PLUGIN_CACHE_ROOT="$REPO_ROOT" sh "$DETECT_SH" 2>&1)
nfind=$(grep -c '^SUITE_HEADER_FINDING=' <<<"$out")
if [ "$(kv "$out" DRIFT_STATE)" = clean ] && [ "$(kv "$out" DRIFT_FAILS)" = 0 ] \
   && [ "$(kv "$out" SUITE_HEADER_STATE)" = fail ] && [ "$(kv "$out" SUITE_HEADER_FAILS)" = 3 ] && [ "$nfind" -eq 3 ] \
   && grep -q "^SUITE_HEADER_FINDING=tests/nested/check-legacy-gamma.sh declares no usable '# ci-subject:' header" <<<"$out"; then
  pass "DET-FAIL: header-less suites are DRIFT_STATE=clean (a stamp cannot repair them) with SUITE_HEADER_STATE=fail, SUITE_HEADER_FAILS=3 and one SUITE_HEADER_FINDING per suite"
else
  failc "DET-FAIL: $(grep -E '^(DRIFT_STATE|DRIFT_FAILS|SUITE_HEADER_)' <<<"$out" | tr '\n' ' ' | cut -c1-500)"
fi

mk_oracle_cache() {  # <dir> <exit> <line...> — a scratch cache whose oracle emits the given lines
  local d="$1" x="$2"; shift 2
  mkdir -p "$d/setup/thin-root-layer"; cp "$MANIFEST" "$d/setup/manifest.json"
  { echo '#!/bin/sh'; for l in "$@"; do printf 'echo "%s"\n' "$l"; done; echo "exit $x"; } > "$d/setup/thin-root-layer/drift-check.sh"
}
OCS="$WORK/oracle-d7-skip"; mk_oracle_cache "$OCS" 0 'PASS: D1 copy: x' 'SKIP: D7 -- suite selector not found beside this script (tried: /a; /b) — suite-header check deferred'
out=$(env TARGET_ROOT="$T" PLUGIN_CACHE_ROOT="$OCS" sh "$DETECT_SH" 2>&1)
if [ "$(kv "$out" SUITE_HEADER_STATE)" = skip ] && [ "$(kv "$out" SUITE_HEADER_FAILS)" = 0 ] \
   && [ "$(kv "$out" SUITE_HEADER_SKIP)" = "suite selector not found beside this script (tried: /a; /b) — suite-header check deferred" ]; then
  pass "DET-SKIP: a SKIP: D7 aggregates to SUITE_HEADER_STATE=skip with the reason carried verbatim on SUITE_HEADER_SKIP"
else
  failc "DET-SKIP: $(grep -E '^SUITE_HEADER_' <<<"$out" | tr '\n' ' ')"
fi
OCE="$WORK/oracle-no-d7"; mk_oracle_cache "$OCE" 0 'PASS: D1 copy: x'
out=$(env TARGET_ROOT="$T" PLUGIN_CACHE_ROOT="$OCE" sh "$DETECT_SH" 2>&1)
if [ "$(kv "$out" SUITE_HEADER_STATE)" = error ] && [ "$(kv "$out" DRIFT_STATE)" = clean ]; then
  pass "DET-ERROR: an oracle that emits no D7 verdict (one predating the leg) -> SUITE_HEADER_STATE=error, never pass; DRIFT unaffected"
else
  failc "DET-ERROR: $(grep -E '^(DRIFT_STATE|SUITE_HEADER_STATE)' <<<"$out" | tr '\n' ' ')"
fi

# -----------------------------------------------------------------------------
echo "== MIGRATED: the adoption procedure's end state =="
# -----------------------------------------------------------------------------
write_suite tests/check-legacy-alpha.sh $'# ci-subject: src/app.txt\n# lane: standing\n# budget-secs: SUITE_BUDGET_CEILING_SECS'
write_suite tests/check-legacy-beta.sh $'# ci-subject: docs/\n# lane: standing\n# budget-secs: SUITE_BUDGET_CEILING_SECS'
write_suite tests/nested/check-legacy-gamma.sh $'# ci-subject: src/**\n# lane: standing\n# budget-secs: SUITE_BUDGET_CEILING_SECS'
g add -A && g commit -q -m migrate
MIGRATED=$(g rev-parse HEAD)
echo v3 > "$T/src/app.txt"; g commit -q -am change-after-migration
SELECTED_WANT=$'tests/check-legacy-alpha.sh\ntests/nested/check-legacy-gamma.sh'

out=$(bash "$SEL" --check-headers 2>"$WORK/chk.err"); rc=$?
if [ "$rc" -eq 0 ] && [ -z "$out" ] && grep -qF "select-suites: headers OK — 3 suite(s) enumerated" "$WORK/chk.err"; then
  pass "MIGRATED-CHECK: --check-headers exits 0 with no suite listed and the headers-OK record"
else
  failc "MIGRATED-CHECK: rc=$rc stdout='$out'; $(cat "$WORK/chk.err")"
fi

out=$(bash "$SEL" --base "$MIGRATED" 2>"$WORK/sel.err"); rc=$?
if [ "$rc" -eq 0 ] && [ "$out" = "$SELECTED_WANT" ] \
   && grep -qF 'NOT-SELECTED: tests/check-legacy-beta.sh ' "$WORK/sel.err" \
   && grep -qF 'SELECTED: tests/nested/check-legacy-gamma.sh ci-subject token src/** matches src/app.txt' "$WORK/sel.err"; then
  pass "MIGRATED-SELECT: the selector narrows by the back-filled tokens — an exact path and a glob select, a directory token outside the delta does not"
else
  failc "MIGRATED-SELECT: rc=$rc stdout='$(tr '\n' '|' <<<"$out")'; $(tr '\n' ' ' < "$WORK/sel.err" | cut -c1-400)"
fi

rm -f "$WITNESS"
out=$(bash "$RUN" --base "$MIGRATED" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && [ "$(witness)" = "$SELECTED_WANT" ]; then
  pass "MIGRATED-RUN: run-suites.sh's selection path executes exactly the two selected suites"
else
  failc "MIGRATED-RUN: rc=$rc witness='$(witness | tr '\n' '|')'; $(tail -n 3 <<<"$out" | tr '\n' ' ')"
fi

out=$(bash "$T/scripts/test/check-suite-manifest.sh" --root "$T" 2>&1); rc=$?
if [ "$rc" -eq 0 ] && contains "$out" "check-suite-manifest: OK — 3 suite(s) declared"; then
  pass "MIGRATED-MANIFEST: the shipped manifest lint accepts the back-filled headers"
else
  failc "MIGRATED-MANIFEST: rc=$rc; $(tr '\n' ' ' <<<"$out" | cut -c1-400)"
fi

run_drift "$T"
out=$(env TARGET_ROOT="$T" PLUGIN_CACHE_ROOT="$REPO_ROOT" sh "$DETECT_SH" 2>&1)
if grep -q '^PASS: D7: suite headers OK — 3 suite(s) enumerated' <<<"$DRIFT_OUT" && ! has "FAIL: D7" \
   && [ "$(kv "$out" SUITE_HEADER_STATE)" = pass ] && [ "$(kv "$out" SUITE_HEADER_FAILS)" = 0 ] \
   && ! grep -qE '^SUITE_HEADER_(FINDING|SKIP)=' <<<"$out"; then
  pass "MIGRATED-D7: drift-check PASS: D7 over 3 suites; detect.sh SUITE_HEADER_STATE=pass with no finding or skip line"
else
  failc "MIGRATED-D7: $(d7); $(grep -E '^SUITE_HEADER_' <<<"$out" | tr '\n' ' ')"
fi

# -----------------------------------------------------------------------------
echo "== DOC: the instructions that consume the BLOCK (AC2) =="
# -----------------------------------------------------------------------------
red=$(region "$GUIDE" '^## RED ' '^## GREEN ')
if contains "$red" "**Derivation on entry**" && contains "$red" 'a `BLOCK:` line it prints is carried into the report'; then
  pass "DOC-RED-DERIVATION: RED's derivation states the BLOCK disposition — the BLOCK lines are carried into the report, never worked around (ADR-0024, #225)"
else
  failc "DOC-RED-DERIVATION: docs/autoflow-guide.md > RED lacks the BLOCK disposition for the suite derivation"
fi
if contains "$red" "**$MIGRATION**" && contains "$red" "select-suites.sh --check-headers" && contains "$red" 'tests/lib/'; then
  pass "DOC-MIGRATION: the section the selector, runner and D7 messages point to exists under RED > Header contract"
else
  failc "DOC-MIGRATION: docs/autoflow-guide.md > RED lacks '$MIGRATION' (the tool messages point to it)"
fi
docre=$(region "$GUIDE" '^#### `doc` re-entry' '^###? ')
if contains "$docre" "the tests the doc diff requires" && contains "$docre" "record the command and its summary line"; then
  pass "DOC-DOC-REMEDY: the doc remedy's step 3 runs what the doc diff requires and records the run (ADR-0024, #225)"
else
  failc "DOC-DOC-REMEDY: docs/autoflow-guide.md > GATE:QUALITY > doc re-entry step 3 lacks the BLOCK disposition"
fi
pre=$(region "$GUIDE" '^## PREFLIGHT' '^## DIAGNOSE')
if contains "$pre" "(D7, issue #213" && contains "$pre" "D7 → back-fill"; then
  pass "DOC-PREFLIGHT: PREFLIGHT names D7 among the drift stop conditions, with its remedy"
else
  failc "DOC-PREFLIGHT: docs/autoflow-guide.md > PREFLIGHT does not name D7 and its remedy"
fi
step1=$(region "$SKILL_MD" '^## Step 1' '^## Step 2')
step4=$(region "$SKILL_MD" '^## Step 4' '^## Step 5')
if contains "$step1" 'SUITE_HEADER_STATE' && contains "$step1" 'SUITE_HEADER_FINDING=' && contains "$step1" 'SUITE_HEADER_SKIP=' \
   && contains "$step1" "$MIGRATION" && contains "$step4" 'FAIL: D7'; then
  pass "SKILL: Step 1 reports the SUITE_HEADER axis with the migration remedy; Step 4 reports the D7 lines after the stamp"
else
  failc "SKILL: plugin/autoflow/skills/install/SKILL.md Step 1 / Step 4 do not report the D7 axis"
fi
if cmp -s "$REPO_ROOT/.claude/agents/autoflow-tester.md" "$REPO_ROOT/plugin/autoflow/agents/autoflow-tester.md" \
   && grep -qF 'carry any `BLOCK:` line it prints into your report' "$REPO_ROOT/plugin/autoflow/agents/autoflow-tester.md"; then
  pass "AGENT-TESTER: both shipped Test AI definitions carry the BLOCK disposition and are identical"
else
  failc "AGENT-TESTER: the Test AI definitions differ or lack the BLOCK disposition"
fi

echo
echo "=============================================="
echo "PASS: $PASS  FAIL: $FAIL"
echo "=============================================="
[ "$FAIL" -eq 0 ] || exit 1
exit 0
