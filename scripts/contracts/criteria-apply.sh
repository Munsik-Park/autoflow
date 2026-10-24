#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
# =============================================================================
# criteria-apply.sh — the criteria-apply module: a script, no model (issue
# #509, epic #507; docs/records/design-reviews/io-contract-modules.md > Q5)
# =============================================================================
# The acceptance criteria a cycle works to: the analysis report's criteria
# (its "## Acceptance criteria" table, columns AC id | criterion | source)
# with every [ac-decision] entry of the given ledger applied, in ledger order.
# Every later module takes the result as its input instead of editing the
# analysis report's table.
#
#   bash <autoflow-root>/scripts/contracts/criteria-apply.sh <invocation.json>
#
# The invocation is the one every module runs on (contract.sh): inputs
# "analysis" (the report) and, when there are decisions, "decisions" (the
# ledger). The script runs contract.sh check-in, applies, writes
# <out>/applied-criteria.json and <out>/tool-requests.json, and runs
# contract.sh check-out.
#
# An [ac-decision] entry (docs/decision-ledger.md > Decision-point entries) is
# a level-2 heading ending in "[ac-decision]" and its "- Key: value" lines:
#   - AC: <id>              the criterion; for added, the id it takes
#   - Disposition: excluded | revised | split | added
#   - Text: <text>          revised, added: the criterion as decided
#   - Into: <id> — <text>   split: one line per criterion it makes
# Text and Into are the lines Q5 adds; today's grammar has only AC and
# Disposition, which say what changes but not into what.
#
# excluded removes the criterion; revised replaces its text; split replaces
# it, in place, by the criteria its Into lines name; added appends one. A
# decision on an id that is not present at its turn, an id that would be
# taken twice, or an entry missing a line its disposition needs refuses the
# run: <out>/result.json names each, and nothing is applied.
#
# Exit: 0 accepted · 1 refused · 2 the invocation or a file cannot be read.
set -uo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
V="$ROOT/scripts/contracts/contract.sh"
die() { printf 'criteria-apply.sh: %s\n' "$*" >&2; exit 2; }
[ $# -eq 1 ] || die "usage: criteria-apply.sh <invocation.json>"
INV=$1
command -v jq >/dev/null 2>&1 || die "jq is required"

bash "$V" check-in "$INV"; rc=$?
[ $rc -eq 0 ] || exit $rc

OUT=$(jq -r .out "$INV")
ANALYSIS=$(jq -r '.inputs.analysis' "$INV")
LEDGER=$(jq -r '.inputs.decisions // empty' "$INV")
MD_JQ=$(cat "$ROOT/scripts/contracts/markdown.jq") || die "cannot read markdown.jq"

refuse() { # <defects json>
  jq -n --argjson d "$1" '{contract: 1, module: "criteria-apply", status: "refused", outputs: {}, defects: $d, tool_requests: []}' \
    >"$OUT/result.json"
  jq -r '.[] | "refused: " + .' <<<"$1" >&2
  exit 1
}

# the analysis report's criteria
CRITERIA=$(jq -Rs "$MD_JQ"' model | pick({under: "Acceptance criteria", header: ["AC id", "criterion", "source"]})
  | if . == null then null else [.rows[] | {id: .[0], text: .[1]}] end' "$ANALYSIS")
[ "$CRITERIA" != null ] || refuse '["the analysis report has no table AC id | criterion | source under the heading ## Acceptance criteria"]'

# the [ac-decision] entries, in ledger order
ENTRIES='[]'
if [ -n "$LEDGER" ]; then
  ENTRIES=$(jq -Rs '
    split("\n") as $L
    | reduce $L[] as $l ({cur: null, out: []};
        if ($l | test("^## ")) then
          (if .cur then .out += [.cur] else . end)
          | .cur = (if ($l | test("\\[ac-decision\\]\\s*$")) then
                      {entry: ($l | capture("^## (?<id>[AO][0-9]+)").id // $l), into: []}
                    else null end)
        elif .cur and ($l | test("^- (AC|Disposition|Text):")) then
          ($l | capture("^- (?<k>[A-Za-z]+):\\s*(?<v>.*)$")) as $m | .cur[$m.k] = ($m.v | gsub("\\s+$"; ""))
        elif .cur and ($l | test("^- Into:")) then
          (($l | capture("^- Into:\\s*(?<id>\\S+)\\s+—\\s+(?<text>.*)$")) // null) as $m
          | .cur.into += [if $m then {id: $m.id, text: ($m.text | gsub("\\s+$"; ""))} else {bad: $l} end]
        else . end)
    | (if .cur then .out + [.cur] else .out end)' "$LEDGER") || die "cannot read the ledger: $LEDGER"
fi

# apply, in order; any defect refuses the whole run
RESULT=$(jq -n --argjson c "$CRITERIA" --argjson e "$ENTRIES" '
  def has_id($id): any(.c[]; .id == $id);
  reduce $e[] as $d ({c: $c, applied: [], defects: []};
    ($d.entry) as $n
    | if ($d.AC // "") == "" then .defects += ["\($n): no AC line"]
      elif ($d.Disposition // "") == "excluded" then
        if has_id($d.AC) then .c |= map(select(.id != $d.AC)) | .applied += [$n]
        else .defects += ["\($n): excluded \($d.AC), which is not present"] end
      elif $d.Disposition == "revised" then
        if ($d.Text // "") == "" then .defects += ["\($n): revised with no Text line"]
        elif has_id($d.AC) then .c |= map(if .id == $d.AC then .text = $d.Text else . end) | .applied += [$n]
        else .defects += ["\($n): revised \($d.AC), which is not present"] end
      elif $d.Disposition == "added" then
        if ($d.Text // "") == "" then .defects += ["\($n): added with no Text line"]
        elif has_id($d.AC) then .defects += ["\($n): added \($d.AC), which is already present"]
        else .c += [{id: $d.AC, text: $d.Text}] | .applied += [$n] end
      elif $d.Disposition == "split" then
        if ($d.into | length) == 0 then .defects += ["\($n): split with no Into line"]
        elif any($d.into[]; has("bad")) then .defects += ["\($n): an Into line is not \"<id> — <text>\""]
        elif (has_id($d.AC) | not) then .defects += ["\($n): split \($d.AC), which is not present"]
        else
          ([.c[].id | select(. != $d.AC)] + [$d.into[].id]) as $ids
          | if ($ids | unique | length) != ($ids | length) then .defects += ["\($n): split \($d.AC) into an id already taken"]
            else .c |= ([.[] | if .id == $d.AC then $d.into[] else . end]) | .applied += [$n] end
        end
      else .defects += ["\($n): Disposition is \"\($d.Disposition // "")\", not excluded, revised, split or added"] end)')

if [ "$(jq '.defects | length' <<<"$RESULT")" -gt 0 ]; then refuse "$(jq -c .defects <<<"$RESULT")"; fi

jq '{criteria: .c, applied: .applied}' <<<"$RESULT" >"$OUT/applied-criteria.json"
echo '[]' >"$OUT/tool-requests.json"
bash "$V" check-out "$INV"
