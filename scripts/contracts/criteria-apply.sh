#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
# =============================================================================
# criteria-apply.sh — the criteria-apply module: a script, no model (issue
# #509, epic #507; docs/records/design-reviews/io-contract-modules.md > Q5)
# =============================================================================
# The acceptance criteria a cycle works to: the analysis report's criteria
# (its "## Acceptance criteria" table, columns AC id | criterion | source)
# with every standing [ac-decision] entry of the given ledger applied, in ledger
# order.
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
#   - Supersedes: <id>      (only on an entry that replaces one)
# Text and Into are the lines Q5 adds; today's grammar has only AC and
# Disposition, which say what changes but not into what. An entry's identifier
# is the heading's leading capital letter and number (O<n>, A<n>, …); the
# letter carries no meaning here, and who wrote an entry (an Authority line)
# is not read: every entry has the same effect.
#
# An entry stands unless a later [ac-decision] entry names it on a
# `- Supersedes:` line (docs/decision-ledger.md > Decision-point entries,
# *Replacement is explicit*); a `- Overrides:` line, which an earlier ledger
# may carry, is read the same. A name two earlier entries share replaces both
# (*ibid.*, *Identifier collision*). Only the standing entries are applied. A
# name that is no earlier [ac-decision] entry, or a line naming no entry,
# refuses the run.
#
# Standing entries on one AC id whose conclusions (Disposition, and Text or
# Into) differ, none naming another, are a conflict, never settled by recency
# (*ibid.*, *Replacement is explicit*): the run is refused. The same
# conclusion recorded twice is not a conflict, and the first of the entries
# alone is applied. A decision on an id a split makes is on another AC id,
# applied in order.
#
# excluded removes the criterion; revised replaces its text; split replaces
# it, in place, by the criteria its Into lines name; added appends one. An
# excluded entry that replaces the entry which added its criterion leaves the
# criterion out: with the replaced entry no longer applied, there is nothing
# to remove, and the decision stands. A
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
                      {entry: ($l | capture("^## (?<id>[A-Z][0-9]+)").id // $l), into: [], replaces: []}
                    else null end)
        elif .cur and ($l | test("^- (AC|Disposition|Text):")) then
          ($l | capture("^- (?<k>[A-Za-z]+):\\s*(?<v>.*)$")) as $m | .cur[$m.k] = ($m.v | gsub("\\s+$"; ""))
        elif .cur and ($l | test("^- (Supersedes|Overrides):")) then
          ($l | capture("^- (?<k>[A-Za-z]+):(?<v>.*)$")) as $m
          | [$m.v | match("\\b[A-Z][0-9]+\\b"; "g").string] as $ids
          | .cur.replaces += (if $ids == [] then [{how: $m.k, id: null}] else [$ids[] | {how: $m.k, id: .}] end)
        elif .cur and ($l | test("^- Into:")) then
          (($l | capture("^- Into:\\s*(?<id>\\S+)\\s+—\\s+(?<text>.*)$")) // null) as $m
          | .cur.into += [if $m then {id: $m.id, text: ($m.text | gsub("\\s+$"; ""))} else {bad: $l} end]
        else . end)
    | (if .cur then .out + [.cur] else .out end)' "$LEDGER") || die "cannot read the ledger: $LEDGER"
fi

# the standing entries: an entry a later one names is replaced, never applied
REPLACED=$(jq -c '
  to_entries as $E
  | reduce $E[] as $x ({gone: [], defects: []};
      $x.value as $d
      | reduce $d.replaces[] as $r (.;
          [$E[:$x.key][] | select(.value.entry == $r.id)] as $t
          | if $r.id == null then .defects += ["\($d.entry): a \($r.how) line names no entry"]
            elif ($t | length) == 0 then .defects += ["\($d.entry): \($r.how) \($r.id), which is no earlier [ac-decision] entry"]
            else .gone += [$t[].key] end))
  | .gone as $g
  # a standing entry keeps the AC ids of the entries it replaces (over)
  | {standing: [$E[] | select(.key as $k | any($g[]; . == $k) | not)
       | .key as $k | .value | . + {over: ([.replaces[].id] as $ids | [$E[:$k][] | select(.value.entry as $e | any($ids[]; . == $e)) | .value.AC])}],
     defects}' <<<"$ENTRIES") || die "cannot resolve the replacements"

# conflicts: standing entries on one AC id whose conclusions differ. A conflict
# keeps every entry, so the application below still names what fails at its turn.
REPLACED=$(jq -c '
  def concl: {d: .Disposition, t: (if .Disposition == "revised" or .Disposition == "added" then .Text else null end),
               i: (if .Disposition == "split" then .into else null end)};
  . as $r
  | [$r.standing | to_entries[] | select((.value.AC // "") != "")] | group_by(.value.AC)
  | reduce .[] as $g ({keep: [], defects: $r.defects};
      if ($g | map(.value | concl) | unique | length) == 1 then .keep += [$g[0].key]
      else .keep += [$g[].key]
        | .defects += ["\($g[0].value.AC): \($g | map(.value.entry) | join(", ")) disagree and none names another, a conflict never settled by recency"] end)
  | .keep as $k
  | {standing: [$r.standing | to_entries[] | select((.value.AC // "") == "" or (.key as $i | any($k[]; . == $i))) | .value], defects}' <<<"$REPLACED") \
  || die "cannot resolve the conflicts"

# apply, in order; any defect refuses the whole run
RESULT=$(jq -n --argjson c "$CRITERIA" --argjson r "$REPLACED" '
  def has_id($id): any(.c[]; .id == $id);
  reduce $r.standing[] as $d ({c: $c, applied: [], defects: $r.defects};
    ($d.entry) as $n
    | if ($d.AC // "") == "" then .defects += ["\($n): no AC line"]
      elif ($d.Disposition // "") == "excluded" then
        if has_id($d.AC) then .c |= map(select(.id != $d.AC)) | .applied += [$n]
        elif any(($d.over // [])[]; . == $d.AC) then .applied += [$n]
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
