#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
# =============================================================================
# contract.sh — the module contract validator (issue #509, epic #507;
# docs/records/design-reviews/io-contract-modules.md > 5.3, Q6)
# =============================================================================
# A module runs between two calls of this script, both on the invocation file
# the Coordinator wrote:
#
#   bash <autoflow-root>/scripts/contracts/contract.sh check-in  <invocation.json>
#   bash <autoflow-root>/scripts/contracts/contract.sh check-out <invocation.json>
#
# The invocation names the module, its params, its inputs by path and its
# output directory:
#
#   { "contract": 1, "module": "design", "params": { "issue": 507 },
#     "inputs": { "applied_criteria": "<path>", ... }, "out": "<directory>" }
#
# The module's contract is <autoflow-root>/docs/contracts/<module>.json. This
# script applies only the checks the contract lists under an output's "checks"
# — the mechanical ones; an output's "evaluation" lines are the evaluation
# module's, and are not read here (Q14: inputs, and the disposition of every
# item the work owes).
#
# check-in  — the params and inputs the contract declares are given and well
#             formed, every input path exists, and an input another module
#             produced comes from a run whose result was accepted. It records
#             what check-out needs (a branch's head) in <out>/.check-in.json.
#             On a refusal it writes <out>/result.json and nothing else.
# check-out — every output the contract declares is there and passes its
#             checks, and the run's tool requests are recorded
#             (<out>/tool-requests.json: a JSON array of {missing, instead},
#             [] when the run lacked nothing — 5.3, Q10). It writes
#             <out>/result.json: the module, accepted or refused, each
#             output's path, each defect found, and the tool requests.
#
# Exit: 0 accepted (check-in: the module may run) · 1 refused (result.json
#       names each defect) · 2 the invocation or the contract cannot be read.
# Requires jq; git for a "git" output; gh for a pull-request output.
set -uo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)

die() { printf 'contract.sh: %s\n' "$*" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || die "jq is required"

# --- the markdown model ------------------------------------------------------
# A markdown file is read as: its lines outside code fences, its level-2
# sections (a "## Delta — round <n>" section flagged as a delta), and its
# tables (header cells, rows, the section each sits under).
MD_JQ='
def cells: sub("^\\s*\\|"; "") | sub("\\|\\s*$"; "")
  | [splits("(?<!\\\\)\\|")] | map(gsub("^\\s+|\\s+$"; ""));
def norm: gsub("`"; "") | gsub("^\\s+|\\s+$"; "");
def model:
  split("\n") as $L
  | reduce range(0; $L | length) as $i (
      {fence: false, sec: null, delta: false, lines: [], sections: [], tables: [], intable: false};
      ($L[$i]) as $l
      | if ($l | test("^\\s*(```|~~~)")) then .fence = (.fence | not) | .intable = false
        elif .fence then .
        elif ($l | test("^## ")) then
          ($l | sub("^## +"; "") | sub("\\s+$"; "")) as $h
          | .sec = $h | .delta = ($h | test("^Delta — round"))
          | .sections += [{heading: $h, delta: .delta, body: []}] | .intable = false
        else
          .lines += [$l]
          | (if (.sections | length) > 0 then .sections[-1].body += [$l] else . end)
          | if ($l | test("^\\s*\\|")) then
              if .intable then
                if (.tables[-1].sep | not) and ($l | test("^\\s*\\|?\\s*:?-{3,}")) then .tables[-1].sep = true
                else .tables[-1].rows += [$l | cells | map(norm)] end
              else .intable = true
                | .tables += [{under: .sec, delta: .delta, header: ($l | cells | map(norm)), sep: false, rows: []}]
              end
            else .intable = false end
        end)
  | {lines, sections, tables: [.tables[] | select(.sep)]};
# the first table matching a check'"'"'s first / header / under / outside_delta
def pick($c):
  [.tables[]
   | select(($c.first == null) or (.header[0] == $c.first))
   | select(($c.header == null) or (.header == $c.header))
   | select(($c.under == null) or (.under == $c.under))
   | select((($c.outside_delta // false) | not) or (.delta | not))] | first;
'

md_model() { jq -Rs "$MD_JQ model" "$1"; }

# --- shared state -------------------------------------------------------------
DEFECTS='[]'
defect() { DEFECTS=$(jq -c --arg d "$*" '. + [$d]' <<<"$DEFECTS"); }

INV=""; OUT=""; MODULE=""; CONTRACT=""; CFILE=""

load() {
  INV=$1
  [ -f "$INV" ] || die "no invocation file: $INV"
  jq -e 'type == "object"' "$INV" >/dev/null 2>&1 || die "the invocation is not a JSON object: $INV"
  MODULE=$(jq -r '.module // empty' "$INV")
  OUT=$(jq -r '.out // empty' "$INV")
  [ -n "$MODULE" ] || die "the invocation names no module"
  [ -n "$OUT" ] || die "the invocation names no output directory (out)"
  case "$MODULE" in */*|.*) die "not a module name: $MODULE" ;; esac
  CFILE="$ROOT/docs/contracts/$MODULE.json"
  [ -f "$CFILE" ] || die "no contract for module $MODULE ($CFILE)"
  CONTRACT=$(jq -c . "$CFILE") || die "the contract is not JSON: $CFILE"
}

# the path(s) an input names, one per line
input_paths() { jq -r --arg n "$1" '.inputs[$n] // empty | if type == "array" then .[] else . end' "$INV"; }
has_input() { [ -n "$(input_paths "$1")" ]; }
param() { jq -r --arg n "$1" '.params[$n] // empty' "$INV"; }

write_result() { # <status>
  mkdir -p "$OUT"
  local tr='[]' outs=${OUTPUTS:-'{}'}
  [ -f "$OUT/tool-requests.json" ] && jq -e 'type == "array"' "$OUT/tool-requests.json" >/dev/null 2>&1 \
    && tr=$(jq -c . "$OUT/tool-requests.json")
  jq -n --arg m "$MODULE" --arg s "$1" --argjson d "$DEFECTS" --argjson o "$outs" --argjson t "$tr" \
    '{contract: 1, module: $m, status: $s, outputs: $o, defects: $d, tool_requests: $t}' >"$OUT/result.json"
}

finish() { # <stage>
  if [ "$(jq length <<<"$DEFECTS")" -gt 0 ]; then
    write_result refused
    jq -r '.[] | "refused: " + .' <<<"$DEFECTS" >&2
    exit 1
  fi
}

# --- check-in -----------------------------------------------------------------
check_in() {
  [ -e "$OUT/result.json" ] && die "the output directory already holds a result: $OUT (a run gets a new directory — 5.3)"
  mkdir -p "$OUT" || die "cannot create the output directory: $OUT"

  local v c
  v=$(jq -r '.contract // empty' "$INV")
  [ "$v" = "$(jq -r .contract <<<"$CONTRACT")" ] || defect "the invocation's contract version is '$v', the contract's $(jq -r .contract <<<"$CONTRACT")"

  # params
  for n in $(jq -r '.params // {} | keys[]' "$INV"); do
    jq -e --arg n "$n" '.params | has($n)' <<<"$CONTRACT" >/dev/null || defect "param '$n' is not one the contract declares"
  done
  while IFS=$'\x1f' read -r n req type pat; do
    [ -n "$n" ] || continue
    v=$(param "$n")
    if [ -z "$v" ]; then [ "$req" = true ] && defect "param '$n' is required"; continue; fi
    case "$type" in
      issue-number|integer) [[ "$v" =~ ^[0-9]+$ ]] && [ "$v" -gt 0 ] || defect "param '$n' is not a positive integer: $v" ;;
    esac
    if [ -n "$pat" ] && ! jq -e -n --arg v "$v" --arg p "$pat" '$v | test($p)' >/dev/null; then
      defect "param '$n' does not match $pat: $v"
    fi
  done < <(jq -r '.params // {} | to_entries[] | [.key, (.value.required // false | tostring), (.value.type // ""), (.value.pattern // "")] | join("\u001f")' <<<"$CONTRACT")

  # inputs
  for n in $(jq -r '.inputs // {} | keys[]' "$INV"); do
    jq -e --arg n "$n" '.inputs | has($n)' <<<"$CONTRACT" >/dev/null || defect "input '$n' is not one the contract declares"
  done
  while IFS=$'\x1f' read -r n req; do
    [ -n "$n" ] || continue
    if ! has_input "$n"; then [ "$req" = true ] && defect "input '$n' is required"; continue; fi
    local srcmods
    srcmods=$(jq -r --arg n "$n" '[.inputs[$n].from] | flatten | map(select(type == "object" and has("module")) | .module) | join(" ")' <<<"$CONTRACT")
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      if [ ! -e "$p" ]; then defect "input '$n': no such file: $p"; continue; fi
      [ -n "$srcmods" ] || continue
      # Q3: the Coordinator re-runs a refused module; its output is never an input.
      local r; r="$(dirname -- "$p")/result.json"
      if [ -f "$r" ]; then
        jq -e '.status == "accepted"' "$r" >/dev/null 2>&1 || defect "input '$n': the run that produced it was not accepted ($r)"
        local m; m=$(jq -r '.module // ""' "$r")
        [[ " $srcmods " == *" $m "* ]] || defect "input '$n': produced by module '$m', not by $srcmods"
      fi
    done < <(input_paths "$n")
  done < <(jq -r '.inputs // {} | to_entries[] | [.key, (.value.required // false | tostring)] | join("\u001f")' <<<"$CONTRACT")

  # what check-out needs: the branch head a git output is counted from
  local start='{}' br head
  for bp in $(jq -r '[.outputs[].checks[]? | select(.type == "git_range") | .branch_param] | unique[]' <<<"$CONTRACT"); do
    br=$(param "$bp")
    [ -n "$br" ] || continue
    if head=$(git rev-parse --verify --quiet "refs/heads/$br^{commit}"); then
      start=$(jq -c --arg b "$br" --arg h "$head" '. + {($b): $h}' <<<"$start")
    else
      defect "branch '$br' (param '$bp') does not exist"
    fi
  done

  finish check-in
  jq -n --arg m "$MODULE" --argjson s "$start" '{module: $m, start_heads: $s}' >"$OUT/.check-in.json"
}

# --- check-out ----------------------------------------------------------------
OUTPUTS='{}'
record_output() { OUTPUTS=$(jq -c --arg n "$1" --argjson v "$2" '. + {($n): $v}' <<<"$OUTPUTS"); }

# ids a "covers" source names, one per line
source_ids() { # <source json> <output-name -> file map json>
  local s=$1 files=$2 kind name p
  if jq -e 'has("input")' <<<"$s" >/dev/null; then
    name=$(jq -r .input <<<"$s")
    while IFS= read -r p; do
      [ -f "$p" ] || continue
      if jq -e 'has("ids")' <<<"$s" >/dev/null; then
        jq -r "[$(jq -r .ids <<<"$s")] | .[] | strings" "$p" 2>/dev/null
      else
        md_model "$p" | jq -r --argjson c "$(jq -c .table <<<"$s")" "$MD_JQ"' pick($c) // {rows: []} | .rows[] | .[0] | select(. != "" and . != "—")'
      fi
    done < <(input_paths "$name")
  else
    name=$(jq -r .output <<<"$s")
    p=$(jq -r --arg n "$name" '.[$n] // empty' <<<"$files")
    [ -f "$p" ] || return 0
    md_model "$p" | jq -r --argjson c "$(jq -c .table <<<"$s")" "$MD_JQ"' pick($c) // {rows: []} | .rows[] | .[0] | select(. != "" and . != "—")'
  fi
}

check_markdown() { # <output name> <file> <checks json> <files map>
  local n=$1 f=$2 checks=$3 files=$4 model c t
  model=$(md_model "$f")
  while IFS= read -r c; do
    t=$(jq -r .type <<<"$c")
    case "$t" in
      section)
        local h; h=$(jq -r .heading <<<"$c")
        jq -e --arg h "$h" 'any(.sections[]; .heading == $h)' <<<"$model" >/dev/null \
          || { defect "$n: no section '## $h'"; continue; }
        jq -e --arg h "$h" 'any(.sections[] | select(.heading == $h) | .body[]; test("\\S"))' <<<"$model" >/dev/null \
          || defect "$n: section '## $h' is empty (write \"none\" when there is nothing)" ;;
      line)
        jq -e --arg p "$(jq -r .pattern <<<"$c")" 'any(.lines[]; test($p))' <<<"$model" >/dev/null \
          || defect "$n: no line matches $(jq -r .pattern <<<"$c")" ;;
      table)
        local tbl desc
        tbl=$(jq -c --argjson c "$c" "$MD_JQ"' pick($c)' <<<"$model")
        desc=$(jq -r --arg q "'" '"the table" + (if .first then " whose first column is " + $q + .first + $q else "" end)
                      + (if .header then " with header " + (.header | join(" | ")) else "" end)
                      + (if .under then " under " + $q + "## " + .under + $q else "" end)
                      + (if .outside_delta then " outside the delta sections" else "" end)' <<<"$c")
        if [ "$tbl" = null ]; then
          # jq's // treats false as absent, so "required": false is read with has()
          [ "$(jq -r 'if has("required") then .required else true end' <<<"$c")" = true ] && defect "$n: no $desc"
          continue
        fi
        if jq -e '.rows_disposed // false' <<<"$c" >/dev/null; then
          while IFS= read -r id; do defect "$n: row '$id' of $desc carries nothing after its first cell"; done \
            < <(jq -r '.rows[] | select(.[1:] | all(. == "")) | .[0]' <<<"$tbl")
        fi
        if jq -e '.unique_first // false' <<<"$c" >/dev/null; then
          while IFS= read -r id; do defect "$n: '$id' names more than one row of $desc"; done \
            < <(jq -r '[.rows[] | .[0]] | group_by(.) | map(select(length > 1) | .[0]) | .[]' <<<"$tbl")
        fi
        local have; have=$(jq -c '[.rows[] | .[0]]' <<<"$tbl")
        while IFS= read -r s; do
          [ -n "$s" ] || continue
          while IFS= read -r id; do
            [ -n "$id" ] || continue
            jq -e --arg id "$id" 'index($id) != null' <<<"$have" >/dev/null || defect "$n: '$id' has no row in $desc"
          done < <(source_ids "$s" "$files" | sed 's/`//g; s/^[[:space:]]*//; s/[[:space:]]*$//')
        done < <(jq -c '.covers // [] | .[]' <<<"$c") ;;
      *) defect "$n: the contract names a check this validator does not know: $t" ;;
    esac
  done < <(jq -c '.[]' <<<"$checks")
}

when_holds() { # <check json> <doc file>: does the check's "when" hold?
  local c=$1 f=$2
  jq -e 'has("when") | not' <<<"$c" >/dev/null && return 0
  if jq -e '.when | has("input")' <<<"$c" >/dev/null; then has_input "$(jq -r .when.input <<<"$c")"; return; fi
  if jq -e '.when | has("key")' <<<"$c" >/dev/null; then
    jq -e --argjson c "$c" "($(jq -r .when.key <<<"$c")) == \$c.when.equals" "$f" >/dev/null 2>&1; return
  fi
  return 0
}

check_json() { # <output name> <file> <checks json>
  local n=$1 f=$2 checks=$3 c t
  jq -e . "$f" >/dev/null 2>&1 || { defect "$n: not JSON: $f"; return; }
  while IFS= read -r c; do
    t=$(jq -r .type <<<"$c")
    case "$t" in
      keys)
        while IFS= read -r k; do
          local spec need=false
          spec=$(jq -c --arg k "$k" '.spec[$k]' <<<"$c")
          if jq -e '.required // false' <<<"$spec" >/dev/null; then need=true
          elif jq -e 'has("required_when")' <<<"$spec" >/dev/null && when_holds "$(jq -c '{when: .required_when}' <<<"$spec")" "$f"; then need=true; fi
          if ! jq -e --arg k "$k" 'has($k)' "$f" >/dev/null; then
            [ "$need" = true ] && defect "$n: key '$k' is required"
            continue
          fi
          local ty; ty=$(jq -r '.type // empty' <<<"$spec")
          [ -z "$ty" ] || jq -e --arg k "$k" --arg t "$ty" '.[$k] | type == $t' "$f" >/dev/null \
            || { defect "$n: key '$k' is not a $ty"; continue; }
          jq -e 'has("const")' <<<"$spec" >/dev/null && { jq -e --arg k "$k" --argjson s "$spec" '.[$k] == $s.const' "$f" >/dev/null \
            || defect "$n: key '$k' is not $(jq -c .const <<<"$spec")"; }
          jq -e 'has("pattern")' <<<"$spec" >/dev/null && { jq -e --arg k "$k" --argjson s "$spec" '.[$k] | test($s.pattern)' "$f" >/dev/null \
            || defect "$n: key '$k' does not match $(jq -r .pattern <<<"$spec")"; }
          jq -e 'has("keys_exactly")' <<<"$spec" >/dev/null && { jq -e --arg k "$k" --argjson s "$spec" '(.[$k] | keys | sort) == ($s.keys_exactly | sort)' "$f" >/dev/null \
            || defect "$n: key '$k' must hold exactly: $(jq -r '.keys_exactly | join(", ")' <<<"$spec")"; }
          jq -e 'has("items_keys")' <<<"$spec" >/dev/null && { jq -e --arg k "$k" --argjson s "$spec" \
            'all(.[$k][]; type == "object" and (. as $i | all($s.items_keys[]; ($i[.] // "") | tostring | test("\\S"))))' "$f" >/dev/null \
            || defect "$n: every item of '$k' must carry $(jq -r '.items_keys | join(", ")' <<<"$spec")"; }
        done < <(jq -r '.spec | keys[]' <<<"$c") ;;
      forbidden_keys)
        while IFS= read -r k; do defect "$n: key '$k' must not be present"; done \
          < <(jq -r --argjson c "$c" '[$c.keys[] as $k | select(has($k)) | $k] | .[]' "$f") ;;
      unique)
        while IFS= read -r id; do defect "$n: '$id' is not unique"; done \
          < <(jq -r "[$(jq -r .path <<<"$c")] | group_by(.) | map(select(length > 1) | .[0]) | .[] | tostring" "$f" 2>/dev/null) ;;
      partition)
        when_holds "$c" "$f" || continue
        local of a b
        of=$(jq -r .of_keys <<<"$c"); a=$(jq -r '.into[0]' <<<"$c"); b=$(jq -r '.into[1]' <<<"$c")
        jq -e "(($of // {}) | keys | sort) as \$all | (($a // []) + ($b // [])) as \$p
               | (\$p | sort) == \$all and (\$p | unique | length) == (\$p | length)" "$f" >/dev/null 2>&1 \
          || defect "$n: every key of $of must be in exactly one of $a and $b" ;;
      covers)
        when_holds "$c" "$f" || continue
        local by dby src name p
        by=$(jq -r .by <<<"$c"); dby=$(jq -r '.disposed_by // empty' <<<"$c")
        name=$(jq -r .source.input <<<"$c")
        while IFS= read -r p; do
          while IFS= read -r id; do
            [ -n "$id" ] || continue
            jq -e --arg id "$id" "[$by] | index(\$id) != null" "$f" >/dev/null 2>&1 \
              || { defect "$n: '$id' (from $name) has no entry in $by"; continue; }
            if [ -n "$dby" ]; then
              local parent=${by%.*}  # the entries holding the matched value
              jq -e --arg id "$id" --arg k "${by##*.}" --arg d "${dby##*.}" \
                "any($parent | select(.[\$k] == \$id); (.[\$d] // \"\") | tostring | test(\"\\\\S\"))" "$f" >/dev/null 2>&1 \
                || defect "$n: the entry for '$id' in $by carries no ${dby##*.}"
            fi
          done < <(jq -r "[$(jq -r .source.ids <<<"$c")] | .[] | strings" "$p" 2>/dev/null)
        done < <(input_paths "$name") ;;
      *) defect "$n: the contract names a check this validator does not know: $t" ;;
    esac
  done < <(jq -c '.[]' <<<"$checks")
}

check_git() { # <output name> <check json>
  local n=$1 c=$2 bp br from to
  bp=$(jq -r .branch_param <<<"$c"); br=$(param "$bp")
  from=$(jq -r --arg b "$br" '.start_heads[$b] // empty' "$OUT/.check-in.json")
  to=$(git rev-parse --verify --quiet "refs/heads/$br^{commit}") || { defect "$n: branch '$br' does not exist"; return; }
  [ -n "$from" ] || { defect "$n: check-in recorded no head for branch '$br'"; return; }
  if [ "$from" = "$to" ]; then defect "$n: no commit on '$br' since check-in"; return; fi
  git merge-base --is-ancestor "$from" "$to" 2>/dev/null || defect "$n: '$br' no longer contains its head at check-in ($from)"
  record_output "$n" "$(jq -n --arg b "$br" --arg f "$from" --arg t "$to" '{branch: $b, from: $f, to: $t}')"
}

check_pr() { # <output name> <checks json>
  local n=$1 checks=$2 c t pr bp br
  command -v gh >/dev/null 2>&1 || { defect "$n: gh is required to read the pull request"; return; }
  bp=$(jq -r '[.[] | select(.type == "pr_open") | .branch_param][0] // empty' <<<"$checks")
  br=$(param "$bp")
  pr=$(gh pr view "$br" --json url,number,isDraft,state,headRefOid,body,statusCheckRollup 2>/dev/null) \
    || { defect "$n: no pull request for branch '$br'"; return; }
  record_output "$n" "$(jq -c '{url, number, head: .headRefOid}' <<<"$pr")"
  while IFS= read -r c; do
    t=$(jq -r .type <<<"$c")
    case "$t" in
      pr_open)
        jq -e '.state == "OPEN"' <<<"$pr" >/dev/null || defect "$n: the pull request is not open"
        jq -e --argjson c "$c" '($c.draft // false | not) or .isDraft' <<<"$pr" >/dev/null || defect "$n: the pull request is not a draft" ;;
      pr_body_covers)
        local name; name=$(jq -r .source.input <<<"$c")
        while IFS= read -r p; do
          while IFS= read -r id; do
            [ -n "$id" ] || continue
            jq -e --arg id "$id" '.body | contains($id)' <<<"$pr" >/dev/null || defect "$n: the body does not state '$id' (from $name)"
          done < <(jq -r "[$(jq -r .source.ids <<<"$c")] | .[] | strings" "$p" 2>/dev/null)
        done < <(input_paths "$name") ;;
      pr_checks)
        if jq -e '(.statusCheckRollup // []) | length > 0' <<<"$pr" >/dev/null; then
          jq -e 'all(.statusCheckRollup[]; ((.conclusion // .state // "") | ascii_upcase) as $s
                   | $s == "SUCCESS" or $s == "NEUTRAL" or $s == "SKIPPED")' <<<"$pr" >/dev/null \
            || defect "$n: a check on the head is not green (failed or still running)"
        else
          jq -e --argjson c "$c" '.body | split("\n") | any(. == $c.not_run_marker)' <<<"$pr" >/dev/null \
            || defect "$n: no check ran on the head and the body has no '$(jq -r .not_run_marker <<<"$c")' line"
        fi ;;
      *) defect "$n: the contract names a check this validator does not know: $t" ;;
    esac
  done < <(jq -c '.[]' <<<"$checks")
}

check_comment() { # <output name> <checks json>
  local n=$1 checks=$2 c pr body repo num
  command -v gh >/dev/null 2>&1 || { defect "$n: gh is required to read the pull request"; return; }
  while IFS= read -r c; do
    pr=$(param "$(jq -r .pr_param <<<"$c")")
    body="$OUT/$(jq -r .body_file <<<"$c")"
    [ -f "$body" ] || { defect "$n: no $(jq -r .body_file <<<"$c")"; continue; }
    repo=${pr%#*}; num=${pr##*#}
    jq -e -Rs --rawfile b "$body" 'split("\u0000") | any(.[]; (. | gsub("\\s+$"; "")) == ($b | gsub("\\s+$"; "")))' \
      < <(gh api --paginate "repos/$repo/issues/$num/comments" --jq '.[].body + "\u0000"' 2>/dev/null) >/dev/null \
      || defect "$n: $(jq -r .body_file <<<"$c") is not posted on $pr"
    record_output "$n" "$(jq -n --arg p "$pr" --arg f "$body" '{pr: $p, file: $f}')"
  done < <(jq -c '.[] | select(.type == "pr_comment_posted")' <<<"$checks")
}

check_out() {
  [ -f "$OUT/.check-in.json" ] || die "no check-in for this run: $OUT/.check-in.json"
  [ -e "$OUT/result.json" ] && die "the run already has a result: $OUT/result.json"

  # every run records its tool requests (5.3, Q10)
  if [ ! -f "$OUT/tool-requests.json" ]; then
    defect "no tool-requests.json ([] when the run lacked nothing)"
  elif ! jq -e 'type == "array" and all(.[]; type == "object"
                 and ((.missing // "") | test("\\S")) and ((.instead // "") | test("\\S")))' "$OUT/tool-requests.json" >/dev/null 2>&1; then
    defect "tool-requests.json is not an array of {missing, instead}"
  fi

  # the files each output names, for checks that read another output
  local files='{}' n fmt file req many
  while IFS=$'\x1f' read -r n file; do
    [ -n "$file" ] && files=$(jq -c --arg n "$n" --arg p "$OUT/$file" '. + {($n): $p}' <<<"$files")
  done < <(jq -r '.outputs | to_entries[] | select(.value.many // false | not) | [.key, (.value.file // "")] | join("\u001f")' <<<"$CONTRACT")

  while IFS=$'\x1f' read -r n fmt file req many; do
    local checks; checks=$(jq -c --arg n "$n" '.outputs[$n].checks // []' <<<"$CONTRACT")
    case "$fmt" in
      git) check_git "$n" "$(jq -c '.[] | select(.type == "git_range")' <<<"$checks")"; continue ;;
      pull-request) check_pr "$n" "$checks"; continue ;;
      pull-request-comment) check_comment "$n" "$checks"; continue ;;
    esac
    if [ "$many" = true ]; then
      local found; found=$(cd "$OUT" 2>/dev/null && compgen -G "$file" | sort)
      if [ -z "$found" ]; then [ "$req" = true ] && defect "$n: no file matches $file"; continue; fi
      record_output "$n" "$(printf '%s\n' "$found" | jq -R --arg o "$OUT" 'select(. != "") | $o + "/" + .' | jq -sc .)"
      continue
    fi
    if [ ! -f "$OUT/$file" ]; then [ "$req" = true ] && defect "$n: no $file"; continue; fi
    record_output "$n" "$(jq -n --arg p "$OUT/$file" '$p')"
    case "$fmt" in
      markdown) check_markdown "$n" "$OUT/$file" "$checks" "$files" ;;
      json) check_json "$n" "$OUT/$file" "$checks" ;;
      *) defect "$n: the contract names a format this validator does not know: $fmt" ;;
    esac
  done < <(jq -r '.outputs | to_entries[] | [.key, .value.format, (.value.file // ""),
                  (if .value | has("required") then .value.required else true end | tostring),
                  (.value.many // false | tostring)] | join("\u001f")' <<<"$CONTRACT")

  finish check-out
  write_result accepted
}

case "${1:-}" in
  check-in)  [ $# -eq 2 ] || die "usage: contract.sh check-in <invocation.json>";  load "$2"; check_in ;;
  check-out) [ $# -eq 2 ] || die "usage: contract.sh check-out <invocation.json>"; load "$2"; check_out ;;
  *) die "usage: contract.sh check-in|check-out <invocation.json>" ;;
esac
