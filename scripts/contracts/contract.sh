#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
# =============================================================================
# contract.sh — the module contract validator (issue #509, epic #507;
# docs/records/design-reviews/io-contract-modules.md > 5.3, Q6)
# =============================================================================
# A module runs between two calls of this script, both on its invocation
# file:
#
#   bash <autoflow-root>/scripts/contracts/contract.sh check-in  <invocation.json>
#   bash <autoflow-root>/scripts/contracts/contract.sh check-out <invocation.json>
#
# The invocation names the module, its params, its inputs — a file by its
# path, several files as an array of paths, the build's commits by their
# range — the attempt's record directory
# when the module reads it, and the run's output directory inside it:
#
#   { "contract": 1, "module": "design", "params": { "issue": 507 },
#     "inputs": { "applied_criteria": "<path>", ... },
#     "records": "<directory>", "out": "<directory>/design-1" }
#   "commits": { "branch": "<branch>", "from": "<commit>", "to": "<commit>" }
#
# The module's contract is <autoflow-root>/docs/contracts/<module>.json. This
# script applies only the checks the contract lists under an output's "checks"
# — the mechanical ones; an output's "evaluation" lines are the evaluation
# module's, and are not read here (Q14: inputs, and the disposition of every
# item the work owes).
#
# check-in  — the params and inputs the contract declares are given and well
#             formed (Q19): an input file exists and, when another module
#             produces it, passes the checks of that module's output that need
#             nothing but the file; a commit range's commits exist, in order,
#             on its branch. Where an input came from is not checked. The run's
#             directory is named <module>[-<qualifier>]-<n>, inside the record
#             directory a module that reads it is given (Q20). It records what
#             check-out needs (a branch's head) in <out>/.check-in.json, and a
#             second check-in of the same run keeps the first's. On a
#             refusal it writes <out>/result.json and nothing else.
# check-out — every output the contract declares is there and passes its
#             checks, and the run's tool requests are recorded
#             (<out>/tool-requests.json: a JSON array of {missing, instead},
#             [] when the run lacked nothing — 5.3, Q10). It writes
#             <out>/result.json: the module, accepted or refused, each
#             output's path, each defect found, the tool requests, and the
#             AutoFlow that ran it — `autoflow`: its version, its root and,
#             for a root that is a git work tree, its HEAD and whether the
#             tree is dirty (ADR-0027 D4). A refusal's result carries the
#             same.
#
# lint      — the contracts agree with each other and with the documents
#             they name (no invocation; §8, the contract–document check):
#
#   bash <autoflow-root>/scripts/contracts/contract.sh lint [<contract.json>...]
#
#             each contract's module is its file name and its kind one of
#             three; its procedure, and every "source" it cites, resolves to
#             a file and, after each " > ", to a heading in it; every input
#             another module produces names a contract and an output it has;
#             every output's format and check types are ones this script
#             implements; every param, input and output a check names is
#             declared; reads_records is true or false; an evaluation
#             contract's score keys are its rubric's items — the Items cell
#             of its row (by the Contract column) in the procedure document's
#             "Evaluation | Gate | Contract | Items" table, and the first
#             column of the "Item" table in its procedure section, when that
#             section has one; and, run on every contract, that the per-module
#             part of docs/autoflow-guide.md is the contracts'
#             (scripts/contracts/gen-module-usage.sh). It prints each
#             disagreement.
#
# Exit: 0 accepted (check-in: the module may run; lint: every contract
#       agrees) · 1 refused (result.json names each defect; lint: the
#       disagreements are printed) · 2 the invocation or the contract cannot
#       be read.
# Requires jq; git for a "git" output; gh for a pull-request output.
set -uo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)

die() { printf 'contract.sh: %s\n' "$*" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || die "jq is required"

# --- the markdown model (markdown.jq) -----------------------------------------
MD_JQ=$(cat "$ROOT/scripts/contracts/markdown.jq") || die "cannot read markdown.jq"

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

# the value(s) an input names, one per line: a path, or a commit range as JSON
input_paths() { jq -r --arg n "$1" '.inputs[$n] // empty | if type == "array" then .[] else . end | if type == "object" then tojson else . end' "$INV"; }
has_input() { [ -n "$(input_paths "$1")" ]; }
param() { jq -r --arg n "$1" '.params[$n] // empty' "$INV"; }

# The AutoFlow that ran the module (ADR-0027 D4): the plugin's version, the
# root it was loaded from and, when that root is a git work tree of its own, its
# HEAD and whether the tree is dirty.
autoflow_run() {
  local v head='' dirty=''
  v=$(jq -r '.version // empty' "$ROOT/.claude-plugin/plugin.json" 2>/dev/null)
  if [ "$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null)" = "$(cd -P -- "$ROOT" && pwd)" ]; then
    head=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null)
    if [ -n "$(git -C "$ROOT" status --porcelain 2>/dev/null)" ]; then dirty=true; else dirty=false; fi
  fi
  jq -nc --arg v "$v" --arg r "$ROOT" --arg h "$head" --arg d "$dirty" \
    '{version: $v, root: $r} + (if $h == "" then {} else {head: $h, dirty: ($d == "true")} end)'
}

write_result() { # <status>
  mkdir -p "$OUT"
  local tr='[]' outs=${OUTPUTS:-'{}'}
  [ -f "$OUT/tool-requests.json" ] && jq -e 'type == "array"' "$OUT/tool-requests.json" >/dev/null 2>&1 \
    && tr=$(jq -c . "$OUT/tool-requests.json")
  jq -n --arg m "$MODULE" --arg s "$1" --argjson d "$DEFECTS" --argjson o "$outs" --argjson t "$tr" \
    --argjson a "$(autoflow_run)" \
    '{contract: 1, module: $m, status: $s, outputs: $o, defects: $d, tool_requests: $t, autoflow: $a}' >"$OUT/result.json"
}

finish() { # <stage>
  if [ "$(jq length <<<"$DEFECTS")" -gt 0 ]; then
    write_result refused
    jq -r '.[] | "refused: " + .' <<<"$DEFECTS" >&2
    exit 1
  fi
}

# every contract, by module
all_contracts() { for f in "$ROOT"/docs/contracts/*.json; do jq -c . "$f" 2>/dev/null; done | jq -sc 'map({key: .module, value: .}) | from_entries'; }

# The checks of an output that need nothing but its file: a "covers" compares
# it with the producer's own inputs or outputs, and a "when" on an input reads
# the producer's invocation — both were the producer's check-out's (Q19).
SELF_CONTAINED='map(select(.type != "covers" and ((.when // {}) | has("input") | not))
  | if .type == "table" then del(.covers) else . end
  | if .type == "keys" then .spec |= map_values(if (.required_when // {}) | has("input") then del(.required_when) else . end) else . end)'

form_defects() { # <format> <file> <checks json>: the defects, as a JSON array
  local saved=$DEFECTS out
  DEFECTS='[]'
  case "$1" in
    markdown) check_markdown form "$2" "$3" '{}' ;;
    json) check_json form "$2" "$3" ;;
  esac
  out=$DEFECTS; DEFECTS=$saved
  printf '%s' "$out"
}

check_range() { # <input name> <range json>: the commits exist, in order, on the branch
  local n=$1 r=$2 br from to
  br=$(jq -r '.branch // empty' <<<"$r" 2>/dev/null); from=$(jq -r '.from // empty' <<<"$r" 2>/dev/null); to=$(jq -r '.to // empty' <<<"$r" 2>/dev/null)
  [ -n "$br" ] && [ -n "$from" ] && [ -n "$to" ] || { defect "input '$n': a commit range is {branch, from, to}: $r"; return; }
  git rev-parse --verify --quiet "refs/heads/$br^{commit}" >/dev/null || { defect "input '$n': branch '$br' does not exist"; return; }
  local c ok=true
  for c in "$from" "$to"; do
    git cat-file -e "$c^{commit}" 2>/dev/null || { defect "input '$n': no commit $c"; ok=false; }
  done
  [ "$ok" = true ] || return
  git merge-base --is-ancestor "$from" "$to" 2>/dev/null || defect "input '$n': $from is not an ancestor of $to"
  git merge-base --is-ancestor "$to" "refs/heads/$br" 2>/dev/null || defect "input '$n': $to is not on branch '$br'"
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

  # the run's directory (Q20)
  local recs base reads
  recs=$(jq -r '.records // empty' "$INV"); base=$(basename -- "$OUT")
  reads=$(jq -r '.reads_records // false' <<<"$CONTRACT")
  [[ "$base" =~ ^$MODULE(-[A-Za-z0-9._]+)*-[0-9]+$ ]] || defect "the output directory is not named $MODULE-<n> or $MODULE-<qualifier>-<n>: $base"
  if [ "$reads" = true ]; then
    if [ -z "$recs" ]; then defect "the module reads the attempt's record directory, and the invocation names no records"
    elif [ ! -d "$recs" ]; then defect "records is not a directory: $recs"
    elif [ "$(cd -P -- "$(dirname -- "$OUT")" && pwd)" != "$(cd -P -- "$recs" && pwd)" ]; then defect "the output directory is not inside records ($recs): $OUT"
    fi
  elif [ -n "$recs" ]; then
    defect "the module judges from its declared inputs, and the invocation names records"
  fi

  # inputs: each of the form the contract asks, wherever it came from (Q19)
  for n in $(jq -r '.inputs // {} | keys[]' "$INV"); do
    jq -e --arg n "$n" '.inputs | has($n)' <<<"$CONTRACT" >/dev/null || defect "input '$n' is not one the contract declares"
  done
  local all; all=$(all_contracts)
  while IFS=$'\x1f' read -r n req; do
    [ -n "$n" ] || continue
    if ! has_input "$n"; then [ "$req" = true ] && defect "input '$n' is required"; continue; fi
    # the outputs this input may be: [{module, output, format, file, checks}]
    local prods
    prods=$(jq -c --arg n "$n" --argjson all "$all" '[[.inputs[$n].from] | flatten[] | select(type == "object" and has("module"))
              | . as $f | ($all[$f.module].outputs[$f.output] // {}) as $o
              | {module: $f.module, output: $f.output, format: ($o.format // ""), checks: ($o.checks // [])}]' <<<"$CONTRACT")
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      if jq -e 'any(.[]; .format == "git")' <<<"$prods" >/dev/null; then check_range "$n" "$p"; continue; fi
      if [ ! -e "$p" ]; then defect "input '$n': no such file: $p"; continue; fi
      jq -e 'length > 0' <<<"$prods" >/dev/null || continue
      [ -f "$p" ] || { defect "input '$n': not a file: $p"; continue; }
      local pr why="" d
      while IFS= read -r pr; do
        d=$(form_defects "$(jq -r .format <<<"$pr")" "$p" "$(jq -c ".checks | $SELF_CONTAINED" <<<"$pr")")
        if [ "$(jq length <<<"$d")" -eq 0 ]; then why=""; break; fi
        why="$why; as $(jq -r '"\(.module) \(.output)"' <<<"$pr"): $(jq -r 'map(sub("^form: "; "")) | join(", ")' <<<"$d")"
      done < <(jq -c '.[]' <<<"$prods")
      [ -z "$why" ] || defect "input '$n': $p is not of the form the contract asks${why}"
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
  # a second check-in of the same run keeps the first's heads, so the commits made in between stay in the range
  [ -f "$OUT/.check-in.json" ] \
    || jq -n --arg m "$MODULE" --argjson s "$start" '{module: $m, start_heads: $s}' >"$OUT/.check-in.json"
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
        if jq -e '.count_only // false' <<<"$c" >/dev/null; then
          # as many entries as the source has items, each disposed of; which entry
          # answers which item is the module's to state
          local want got
          want=0
          while IFS= read -r p; do
            want=$((want + $(jq -r "[$(jq -r .source.ids <<<"$c")] | length" "$p" 2>/dev/null || echo 0)))
          done < <(input_paths "$name")
          got=$(jq -r "[$by] | length" "$f" 2>/dev/null || echo 0)
          [ "$got" -ge "$want" ] || defect "$n: $by has $got entries for the $want items of $name"
          if [ -n "$dby" ]; then
            jq -e "[try ($dby)] | all((. // \"\") | tostring | test(\"\\\\S\"))" "$f" >/dev/null 2>&1 || defect "$n: an entry of $by carries no ${dby##*.}"
          fi
          continue
        fi
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

check_git() { # <output name> <check json> <files map>
  local n=$1 c=$2 files=$3 bp br from to
  bp=$(jq -r .branch_param <<<"$c"); br=$(param "$bp")
  from=$(jq -r --arg b "$br" '.start_heads[$b] // empty' "$OUT/.check-in.json")
  to=$(git rev-parse --verify --quiet "refs/heads/$br^{commit}") || { defect "$n: branch '$br' does not exist"; return; }
  [ -n "$from" ] || { defect "$n: check-in recorded no head for branch '$br'"; return; }
  if [ "$from" = "$to" ]; then
    # Q19: no commit is not a defect when the run says why
    local ar rf h
    ar=$(jq -c '.absent_reason // empty' <<<"$c")
    if [ -n "$ar" ]; then
      rf=$(jq -r --arg o "$(jq -r .output <<<"$ar")" '.[$o] // empty' <<<"$files"); h=$(jq -r .section <<<"$ar")
      if [ -f "$rf" ] && md_model "$rf" | jq -e --arg h "$h" 'any(.sections[] | select(.heading == $h) | .body[]; test("\\S"))' >/dev/null; then
        record_output "$n" "$(jq -n --arg b "$br" --arg f "$from" '{branch: $b, from: $f, to: $f}')"
        return
      fi
      defect "$n: no commit on '$br' since check-in, and no '## $h' section in $(basename -- "${rf:-the report}") says why"
    else
      defect "$n: no commit on '$br' since check-in"
    fi
    return
  fi
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
    # the bodies as one JSON array (each page is an array); compared with the
    # file, leading and trailing whitespace aside
    local bodies
    bodies=$(gh api --paginate "repos/$repo/issues/$num/comments" 2>/dev/null | jq -sc 'add // [] | map(.body // "")' 2>/dev/null) || bodies='[]'
    jq -e -n --argjson bs "${bodies:-[]}" --rawfile b "$body" \
      'def t: gsub("^\\s+|\\s+$"; ""); ($b | t) as $want | any($bs[]; t == $want)' >/dev/null \
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
      git) check_git "$n" "$(jq -c '.[] | select(.type == "git_range")' <<<"$checks")" "$files"; continue ;;
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

# --- lint ---------------------------------------------------------------------
# The check types each format implements above; lint refuses any other.
KNOWN_TYPES='{"markdown": ["section", "table"],
  "json": ["keys", "forbidden_keys", "unique", "partition", "covers"],
  "git": ["git_range"], "pull-request": ["pr_open", "pr_checks"],
  "pull-request-comment": ["pr_comment_posted"]}'

# does "<path> > <heading> > <heading>…" resolve under ROOT?
ref_resolves() { # <reference>
  local ref=$1 path rest h line=0 n
  ref=$(sed -E 's/ \([^)]*\)$//' <<<"$ref")
  path=${ref%% > *}
  [ -e "$ROOT/$path" ] || { echo "no file $path"; return 1; }
  [ "$path" = "$ref" ] && return 0
  rest=${ref#* > }
  while [ -n "$rest" ]; do
    h=${rest%% > *}
    [ "$h" = "$rest" ] && rest="" || rest=${rest#* > }
    h=$(sed -E 's/ \([^)]*\)$//' <<<"$h")
    n=$(awk -v h="$h" -v from="$line" 'NR > from && /^#+ / { t = $0; sub(/^#+ +/, "", t); sub(/ +$/, "", t); if (t == h) { print NR; exit } }' "$ROOT/$path")
    [ -n "$n" ] || { echo "no heading '$h' in $path after line $line"; return 1; }
    line=$n
  done
}

# the first column of the "Item" table in the section a reference names, or
# nothing when the section has none
section_items() { # <reference>
  local ref path rest h line=0 level n
  ref=$(sed -E 's/ \([^)]*\)$//' <<<"$1"); path=${ref%% > *}; rest=${ref#* > }
  while [ -n "$rest" ]; do
    h=${rest%% > *}
    [ "$h" = "$rest" ] && rest="" || rest=${rest#* > }
    h=$(sed -E 's/ \([^)]*\)$//' <<<"$h")
    n=$(awk -v h="$h" -v from="$line" 'NR > from && /^#+ / { t = $0; sub(/^#+ +/, "", t); sub(/ +$/, "", t); if (t == h) { print NR; exit } }' "$ROOT/$path")
    [ -n "$n" ] || return 0
    line=$n
  done
  level=$(sed -n "${line}p" "$ROOT/$path" | sed -E 's/^(#+).*/\1/' | tr -d '\n' | wc -c)
  awk -v from="$line" -v lv="$level" 'NR > from && /^#+ / { l = $0; sub(/ .*/, "", l); if (length(l) <= lv) exit } NR > from' "$ROOT/$path" \
    | jq -Rsc "$MD_JQ model | pick({first: \"Item\"}) | if . == null then empty else [.rows[][0]] end"
}

# an evaluation contract's score keys against its rubric's items (§8)
rubric_disagreements() { # <contract json>
  local c=$1 keys path items
  keys=$(jq -c '[.outputs[].checks[]? | select(.type == "keys") | .spec.scores.keys_exactly // empty] | first // empty' <<<"$c")
  [ -n "$keys" ] || { echo "no scores keys_exactly to check against the rubric"; return; }
  path=$(jq -r '.procedure // "" | sub(" > .*$"; "")' <<<"$c")
  [ -f "$ROOT/$path" ] || return 0
  items=$(md_model "$ROOT/$path" | jq -c --arg m "$(jq -r .module <<<"$c")" "$MD_JQ"'
    pick({header: ["Evaluation", "Gate", "Contract", "Items"]})
    | if . == null then null else ([.rows[] | select(.[2] == $m) | .[3] | split(", ")] | first) end')
  if [ -z "$items" ]; then
    echo "cannot read the rubric's items from $path"
  elif [ "$items" = null ]; then
    echo "no row for $(jq -r .module <<<"$c") in the Evaluation | Gate | Contract | Items table of $path"
  else
    jq -r --argjson k "$keys" --argjson i "$items" --arg w "$path > Evaluation Types" '
      (($i - $k) | map("scores lacks the rubric item \(.) (\($w))")[]),
      (($k - $i) | map("scores key \(.) is not a rubric item (\($w))")[])' <<<'null'
  fi
  items=$(section_items "$(jq -r '.procedure // ""' <<<"$c")")
  [ -n "$items" ] && jq -r --argjson k "$keys" --argjson i "$items" --arg w "$(jq -r .procedure <<<"$c")" '
    (($i - $k) | map("scores lacks the rubric item \(.) (\($w))")[]),
    (($k - $i) | map("scores key \(.) is not a rubric item (\($w))")[])' <<<'null'
  return 0
}

lint() {
  local files=("$@") f c m why bad=0
  [ ${#files[@]} -gt 0 ] || files=("$ROOT"/docs/contracts/*.json)
  local all; all=$(all_contracts)
  say() { printf '%s: %s\n' "$(basename "$f")" "$*"; bad=1; }
  for f in "${files[@]}"; do
    c=$(jq -c . "$f" 2>/dev/null) || { say "not JSON"; continue; }
    m=$(jq -r '.module // ""' <<<"$c")
    [ "$m.json" = "$(basename "$f")" ] || say "module '$m' is not the file's name"
    jq -e '.contract == 1' <<<"$c" >/dev/null || say "contract is not 1"
    jq -e '.kind | IN("functional", "evaluation", "deterministic")' <<<"$c" >/dev/null || say "kind is not functional, evaluation or deterministic"
    jq -e '(.goal // "") | test("\\S")' <<<"$c" >/dev/null || say "no goal"
    jq -e '.reads_records | type == "boolean"' <<<"$c" >/dev/null || say "reads_records is not true or false"
    why=$(ref_resolves "$(jq -r '.procedure // ""' <<<"$c")") || say "procedure: $why"
    while IFS= read -r r; do
      [ -n "$r" ] || continue
      why=$(ref_resolves "$r") || say "source '$r': $why"
    done < <(jq -r '.. | objects | .source? // empty | strings | split("; ")[]' <<<"$c")
    # inputs another module produces
    local found
    found=$(jq -r --argjson all "$all" '
      .inputs // {} | to_entries[] | .key as $k | ([.value.from] | flatten[])
      | . as $f
      | if type != "object" then "input \($k): from is not an object"
        elif has("module") then
          if ($all[$f.module] | not) then "input \($k): no contract for module \($f.module)"
          elif ($all[$f.module].outputs | has($f.output) | not) then "input \($k): module \($f.module) has no output \($f.output)"
          else empty end
        elif has("ledger") then empty
        elif has("path") then (if .path | IN("target", "invocation") then empty else "input \($k): path is not target or invocation" end)
        elif has("results") then (if .results == "tool_requests" then empty else "input \($k): results is not tool_requests" end)
        else "input \($k): from names no module, ledger, path or results" end' <<<"$c") || say "inputs cannot be read"
    while IFS= read -r line; do [ -n "$line" ] && say "$line"; done <<<"$found"
    # outputs: formats, check types, and what each check names
    found=$(jq -r --argjson known "$KNOWN_TYPES" '
      . as $c | .outputs // {} | to_entries[] | .key as $o | .value as $v
      | if ($known | has($v.format) | not) then "output \($o): format \($v.format) is not one the validator reads"
        else
          ($v.checks // [])[] as $ch
          | (if ($known[$v.format] | index($ch.type)) == null then "output \($o): check type \($ch.type) is not one the validator implements for \($v.format)" else empty end),
            ([$ch.branch_param, $ch.pr_param][] | select(. != null) | . as $p | select(($c.params // {}) | has($p) | not) | "output \($o): param \(.) is not declared"),
            ([$ch.when.input, $ch.source.input, ($ch.covers // [])[].input][] | select(. != null)
              | . as $i | select(($c.inputs // {}) | has($i) | not) | "output \($o): input \(.) is not declared"),
            ([($ch.covers // [])[].output, $ch.absent_reason.output][] | select(. != null) | . as $x | select(($c.outputs // {}) | has($x) | not) | "output \($o): output \(.) is not declared"),
            (if $ch.absent_reason and ($c.outputs[$ch.absent_reason.output].format // "") != "markdown" then "output \($o): absent_reason names an output that is not markdown" else empty end)
        end' <<<"$c") || say "outputs cannot be read"
    while IFS= read -r line; do [ -n "$line" ] && say "$line"; done <<<"$found"
    # an evaluation's score keys are its rubric's items
    if jq -e '.kind == "evaluation"' <<<"$c" >/dev/null; then
      found=$(rubric_disagreements "$c")
      while IFS= read -r line; do [ -n "$line" ] && say "$line"; done <<<"$found"
    fi
  done
  # the guide's per-module part is the contracts'
  if [ $# -eq 0 ] && ! bash "$ROOT/scripts/contracts/gen-module-usage.sh" --check 2>/dev/null; then
    f=autoflow-guide.md; say "differs from the contracts — run: bash scripts/contracts/gen-module-usage.sh"
  fi
  return $bad
}

case "${1:-}" in
  check-in)  [ $# -eq 2 ] || die "usage: contract.sh check-in <invocation.json>";  load "$2"; check_in ;;
  check-out) [ $# -eq 2 ] || die "usage: contract.sh check-out <invocation.json>"; load "$2"; check_out ;;
  lint)      shift; lint "$@"; exit $? ;;
  *) die "usage: contract.sh check-in|check-out <invocation.json> | lint [<contract.json>...]" ;;
esac
