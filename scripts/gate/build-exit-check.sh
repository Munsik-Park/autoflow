#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# U4 Build-and-verify exit check (ADR-0025 D3)
# =============================================================================
# The U4 unit's exit is this check plus the `audit` gate. What the former
# phase split enforced by separating roles — the test written and seen failing
# before the implementation, every automated row run, the manual checklist
# itemized, the maintained documents updated, the lint chain run on every
# commit — is checked here, deterministically, against two files the unit
# writes and one it reads:
#
#   .autoflow/issue-{N}-verification-design.md   the design table (U3's)
#   .autoflow/issue-{N}-build-report.md          the unit's build report
#
# and against git. The build report's machine-read sections and their table
# columns are defined in docs/phases/build.md > Build report; a table is
# located by its header row, so column order is free.
#
# Two kinds of finding, kept apart because the rules treat them apart:
#   FAIL:     a defect — the test-first order not shown, a recorded Red line
#             or a non-zero Red exit (`exit: <n>`) the Red log does not
#             carry, a run recorded as failing, an
#             observation mismatch, a listed document the diff does not touch,
#             a lint chain `detected`, a required report section absent.
#   NOT-RUN:  an omission — a design row with no run record, a record with no
#             log behind it or a line its log does not carry, a commit with no
#             lint record, a chain `not-run (unexecuted)`. An omission is filled
#             where it is found, never gated (docs/submodule-common-rules.md >
#             Verification and Tools > *A missing run is filled where it is
#             found*).
#
# Usage
#   build-exit-check.sh --issue <N> [--base <rev>] [--dir <autoflow-dir>]
#     --base  the cycle's base commit; default: the merge-base of HEAD and the
#             remote default branch (refs/remotes/origin/HEAD, else origin/main)
#     --dir   the .autoflow directory; default: ./.autoflow
#
# Output: one line per finding (`FAIL: …`, `NOT-RUN: …`), then one verdict
# line `build-exit-check: <pass|defect|omission> fail=<n> not-run=<n> base=<sha> head=<sha>`.
#
# Exit codes: 0 pass · 1 at least one FAIL · 3 NOT-RUN only · 2 usage / input
# missing / unresolvable base.
# =============================================================================

set -uo pipefail

usage() {
  sed -n '/^# Usage/,/^# Exit codes/p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

ISSUE="" BASE_REV="" DIR=".autoflow"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --issue) [ "$#" -ge 2 ] || usage; ISSUE=$2; shift 2 ;;
    --base) [ "$#" -ge 2 ] || usage; BASE_REV=$2; shift 2 ;;
    --dir) [ "$#" -ge 2 ] || usage; DIR=$2; shift 2 ;;
    *) usage ;;
  esac
done
case "$ISSUE" in ''|*[!0-9]*) usage ;; esac

DESIGN="$DIR/issue-$ISSUE-verification-design.md"
REPORT="$DIR/issue-$ISSUE-build-report.md"
for f in "$DESIGN" "$REPORT"; do
  if [ ! -r "$f" ]; then
    echo "build-exit-check: input missing: $f" >&2
    exit 2
  fi
done

HEAD_SHA=$(git rev-parse --verify -q HEAD) || { echo "build-exit-check: no HEAD" >&2; exit 2; }
if [ -z "$BASE_REV" ]; then
  _def=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || true)
  [ -n "$_def" ] || _def=origin/main
  BASE_REV=$(git merge-base HEAD "$_def" 2>/dev/null) || { echo "build-exit-check: cannot resolve the base (merge-base HEAD $_def); pass --base" >&2; exit 2; }
fi
BASE_SHA=$(git rev-parse --verify -q "$BASE_REV^{commit}") || { echo "build-exit-check: unresolvable base: $BASE_REV" >&2; exit 2; }

NFAIL=0 NNOTRUN=0
fail() { echo "FAIL: $*"; NFAIL=$((NFAIL + 1)); }
notrun() { echo "NOT-RUN: $*"; NNOTRUN=$((NNOTRUN + 1)); }

# table <file> <col>... — print the rows of every markdown table whose header
# row names all the given columns, one row per line, the requested cells
# joined by a TAB in the order asked. A cell is split on `|` outside a
# backtick span and not escaped as `\|`; surrounding spaces and one pair of
# enclosing backticks are stripped. A table ends at the first line that does
# not start with `|`. Each table is preceded by a line `#TABLE`.
table() {
  local file=$1 IFS='|'; shift
  awk -v want="$*" '
    function split_cells(line, out,   n, i, c, cur, tick, prev) {
      n = 0; cur = ""; tick = 0; prev = ""
      sub(/^[[:space:]]*\|/, "", line); sub(/\|[[:space:]]*$/, "", line)
      for (i = 1; i <= length(line); i++) {
        c = substr(line, i, 1)
        if (c == "`") tick = !tick
        if (c == "|" && !tick && prev != "\\") { out[++n] = cur; cur = ""; prev = c; continue }
        if (c == "|" && prev == "\\") cur = substr(cur, 1, length(cur) - 1)
        cur = cur c; prev = c
      }
      out[++n] = cur
      for (i = 1; i <= n; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", out[i])
        if (out[i] ~ /^`.*`$/ && length(out[i]) >= 2) out[i] = substr(out[i], 2, length(out[i]) - 2)
      }
      return n
    }
    BEGIN { nw = split(want, w, "|") }
    {
      if ($0 !~ /^[[:space:]]*\|/) { intable = 0; hdr = 0; next }
      if (!intable) {
        intable = 1; hdr = 0
        n = split_cells($0, cell)
        ok = 1
        for (j = 1; j <= nw; j++) {
          col[j] = 0
          for (i = 1; i <= n; i++) if (cell[i] == w[j]) col[j] = i
          if (!col[j]) ok = 0
        }
        if (ok) { hdr = 1; print "#TABLE" }
        next
      }
      if (!hdr) next
      if ($0 ~ /^[[:space:]]*\|[-:| ]+\|?[[:space:]]*$/) next
      n = split_cells($0, cell)
      row = ""
      for (j = 1; j <= nw; j++) row = row (j > 1 ? "\t" : "") cell[col[j]]
      print row
    }
  ' "$file"
}

# section_has <file> <heading> — true when a level-2 heading equal to <heading> exists.
section_has() { grep -qxF "## $2" "$1"; }

# section_body <file> <heading> — the lines under a level-2 heading, to the next one.
section_body() {
  awk -v h="## $2" '$0 == h { on = 1; next } /^## / { on = 0 } on' "$1"
}

# required design rows per Issue AC, for a type predicate; the last table that
# names an AC decides that AC's count (a later table restates it).
design_counts() {  # <awk condition over t (Type) and k (Kind)>
  table "$DESIGN" "Issue AC" "Type" "Kind" | awk -F '\t' -v cond="$1" '
    function flush(  a) { for (a in cur) req[a] = cur[a]; split("", cur) }
    $0 == "#TABLE" { flush(); next }
    {
      t = $2; k = $3; hit = 0
      if (cond == "redfirst") hit = (t ~ /^automated/ && (k == "driving" || k == "regression"))
      if (cond == "run") hit = (t ~ /^automated/ || t ~ /^delivery-check/)
      if (cond == "manual") hit = (t ~ /^manual/)
      if (!($1 in cur)) cur[$1] = 0
      if (hit) cur[$1]++
    }
    END { flush(); for (a in req) if (req[a] > 0) print a "\t" req[a] }
  '
}

report_rows() { table "$REPORT" "$@" | grep -v '^#TABLE$' || true; }

count_rows_for() {  # <rows> <ac>
  printf '%s\n' "$1" | awk -F '\t' -v a="$2" '$1 == a { n++ } END { print n + 0 }'
}

is_ancestor() { git merge-base --is-ancestor "$1" "$2" 2>/dev/null; }

# ── Required report sections ──
for h in "Test-first" "Run record" "Manual checklist" "Maintained documents" "Lint" \
         "Scope judgments" "Out-of-scope observations — guard / boundary logic touched" \
         "Comment check" "Test files kept"; do
  section_has "$REPORT" "$h" || fail "report: section '## $h' is absent"
done

# ── (a) test-first ──
TF=$(report_rows "Issue AC" "Test" "Red at" "Red log" "Red line" "Red exit" "Impl commit")
while IFS=$'\t' read -r ac need; do
  [ -n "$ac" ] || continue
  have=$(count_rows_for "$TF" "$ac")
  [ "$have" -ge "$need" ] || fail "test-first: $ac has $need driving/regression row(s) in the design and $have Test-first row(s)"
done < <(design_counts redfirst)
while IFS=$'\t' read -r ac test redat redlog redline redexit impl; do
  [ -n "$ac" ] || continue
  r=$(git rev-parse --verify -q "$redat^{commit}" 2>/dev/null) || { fail "test-first: $ac — Red at '$redat' is not a commit"; continue; }
  i=$(git rev-parse --verify -q "$impl^{commit}" 2>/dev/null) || { fail "test-first: $ac — Impl commit '$impl' is not a commit"; continue; }
  if ! is_ancestor "$i" "$HEAD_SHA" || is_ancestor "$i" "$BASE_SHA"; then
    fail "test-first: $ac — Impl commit ${i:0:12} is not a commit of this branch (base ${BASE_SHA:0:12}..HEAD)"
  fi
  if [ "$r" = "$i" ] || ! is_ancestor "$r" "$i"; then
    fail "test-first: $ac — the Red run (at ${r:0:12}) does not precede the implementation commit ${i:0:12}"
  fi
  case "$test" in
    .autoflow/*) [ -f "$test" ] || fail "test-first: $ac — test $test is absent" ;;
  esac
  if [ ! -s "$redlog" ]; then
    fail "test-first: $ac — Red log $redlog is absent or empty"
  elif [ -z "$redline" ] || ! grep -qF -- "$redline" "$redlog"; then
    fail "test-first: $ac — Red log $redlog does not carry the recorded Red line"
  fi
  case "$redexit" in
    ''|*[!0-9]*|0) fail "test-first: $ac — Red exit '$redexit' is not a failing exit status" ;;
    *) [ -s "$redlog" ] && grep -qxE "exit: ${redexit}[[:space:]]*" "$redlog" \
         || fail "test-first: $ac — Red log $redlog does not carry 'exit: $redexit'" ;;
  esac
done <<< "$TF"

# ── (b) run record ──
RR=$(report_rows "Issue AC" "Command" "Log" "Summary line" "Result")
while IFS=$'\t' read -r ac need; do
  [ -n "$ac" ] || continue
  have=$(count_rows_for "$RR" "$ac")
  [ "$have" -ge "$need" ] || notrun "run: $ac has $need automated/delivery-check row(s) in the design and $have run record(s)"
done < <(design_counts run)
while IFS=$'\t' read -r ac cmd log line result; do
  [ -n "$ac" ] || continue
  if [ ! -s "$log" ]; then
    notrun "run: $ac — log $log is absent or empty ($cmd)"
  elif [ -z "$line" ] || ! grep -qF -- "$line" "$log"; then
    notrun "run: $ac — log $log does not carry the recorded summary line"
  elif [ "$result" != "pass" ]; then
    fail "run: $ac — recorded result '$result' ($log)"
  fi
done <<< "$RR"

# ── (c) manual checklist ──
MC=$(report_rows "Issue AC" "Executor" "Record")
while IFS=$'\t' read -r ac need; do
  [ -n "$ac" ] || continue
  have=$(count_rows_for "$MC" "$ac")
  [ "$have" -ge "$need" ] || notrun "manual: $ac has $need manual row(s) in the design and $have checklist item(s)"
done < <(design_counts manual)
while IFS=$'\t' read -r ac executor record; do
  [ -n "$ac" ] || continue
  case "$executor" in
    person)
      [ "$record" = "delegated to user" ] || fail "manual: $ac — a person-executed item's record is '$record', not 'delegated to user'"
      ;;
    AI:*)
      if [ ! -s "$record" ]; then
        notrun "manual: $ac — observation record $record is absent"
      elif grep -qE '^observation: match[[:space:]]*$' "$record"; then
        :
      elif grep -qE '^observation: mismatch' "$record"; then
        fail "manual: $ac — $record records a mismatch"
      else
        notrun "manual: $ac — $record carries no result line"
      fi
      ;;
    *) fail "manual: $ac — executor '$executor' is neither 'AI: <tool>' nor 'person'" ;;
  esac
done <<< "$MC"

# ── (d) maintained documents ──
if section_has "$REPORT" "Maintained documents"; then
  MD=$(section_body "$REPORT" "Maintained documents" | grep -E '^[[:space:]]*- ' || true)
  if [ -z "$MD" ]; then
    fail "docs: '## Maintained documents' lists nothing — list each document, or 'none — <reason>'"
  elif ! printf '%s\n' "$MD" | grep -qE '^[[:space:]]*- none — .+'; then
    CHANGED=$(git diff --name-only "$BASE_SHA" "$HEAD_SHA")
    while IFS= read -r l; do
      p=$(printf '%s' "$l" | sed -nE 's/^[[:space:]]*- `([^`]+)`.*/\1/p')
      if [ -z "$p" ]; then
        fail "docs: entry names no \`path\`: $l"
      elif ! printf '%s\n' "$CHANGED" | grep -qxF -- "$p"; then
        fail "docs: $p is listed as updated and the diff ${BASE_SHA:0:12}..HEAD does not touch it"
      fi
    done <<< "$MD"
  fi
fi

# ── (e) lint record per commit ──
LT=$(report_rows "Commit" "Chain" "Outcome")
while IFS= read -r c; do
  [ -n "$c" ] || continue
  rows=$(printf '%s\n' "$LT" | awk -F '\t' -v c="$c" 'length($1) >= 7 && index(c, $1) == 1')
  if [ -z "$rows" ]; then
    notrun "lint: commit ${c:0:12} has no lint record"
    continue
  fi
  while IFS=$'\t' read -r _ chain outcome; do
    case "$outcome" in
      clean|fixed-and-staged|not-covered|not-applicable|"not-run (ci-deferred)") ;;
      "not-run (unexecuted)") notrun "lint: commit ${c:0:12} — chain '$chain' not-run (unexecuted)" ;;
      detected) fail "lint: commit ${c:0:12} — chain '$chain' detected findings" ;;
      *) fail "lint: commit ${c:0:12} — chain '$chain' outcome '$outcome' is outside the vocabulary" ;;
    esac
  done <<< "$rows"
done < <(git rev-list "$BASE_SHA..$HEAD_SHA")

if [ "$NFAIL" -gt 0 ]; then verdict=defect; rc=1
elif [ "$NNOTRUN" -gt 0 ]; then verdict=omission; rc=3
else verdict=pass; rc=0; fi
echo "build-exit-check: $verdict fail=$NFAIL not-run=$NNOTRUN base=$BASE_SHA head=$HEAD_SHA"
exit "$rc"
