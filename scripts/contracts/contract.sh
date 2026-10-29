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
# path, several files as an array of paths — the attempt's record directory
# when the module reads it, the run's output directory inside it and, when
# the invocation has any, its instructions — what the module does beyond its
# output directory, in place of its default (ADR-0040 D5):
#
#   { "contract": 1, "module": "design", "params": { "issue": 507 },
#     "inputs": { "applied_criteria": "<path>", ... },
#     "records": "<directory>", "out": "<directory>/design-1",
#     "instructions": "<text>" }
#
# The module's contract is <autoflow-root>/docs/contracts/<module>.json. This
# script applies only the checks the contract lists under an output's "checks"
# — the form of a file, read from that file alone (ADR-0040 D2); an output's
# "evaluation" lines are the evaluation modules' — the disposition of every
# item the work owes among them — and are not read here.
#
# check-in  — the params and inputs the contract declares are given and well
#             formed (Q19): an input file exists and, when another module
#             produces it, passes the checks of that module's output. Where an
#             input came from is not checked. The run's directory is named
#             <module>[-<qualifier>]-<n>, inside the record directory a module
#             that reads it is given (Q20). It marks the run checked in
#             (<out>/.check-in.json). On a refusal it writes <out>/result.json
#             and nothing else.
# check-out — every output the contract declares is there and passes its
#             checks, and the run's tool requests are recorded
#             (<out>/tool-requests.json: a JSON array of {missing, instead},
#             [] when the run lacked nothing — 5.3, Q10). It writes
#             <out>/result.json: the module, accepted, refused or failed,
#             each output's path, each defect found, the tool requests, and
#             the AutoFlow that ran it — `autoflow`: its version, its root
#             and, for a root that is a git work tree, its HEAD and whether
#             the tree is dirty (ADR-0027 D4). A refusal's result carries the
#             same. A contract may declare one output its failure output
#             ("failure": true): a run that wrote it ended short of its
#             expected output and says what it did and why; check-out then
#             checks that file is not empty and the tool requests, records
#             every output present, and writes `failed` (ADR-0039 D3).
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
#             implements, and no check names an input; reads_records is true
#             or false; an evaluation contract's score keys are its rubric's
#             items — the Items cell of its row (by the Contract column) in
#             the procedure document's "Evaluation | Gate | Contract | Items"
#             table, and the first column of the "Item" table in its
#             procedure section, when that section has one; and, run on
#             every contract, that the per-module part of
#             docs/autoflow-guide.md is the contracts'
#             (scripts/contracts/gen-module-usage.sh). It prints each
#             disagreement.
#
# Exit: 0 accepted (check-in: the module may run; lint: every contract
#       agrees) · 1 refused (result.json names each defect; lint: the
#       disagreements are printed) · 2 the invocation or the contract cannot
#       be read · 3 failed (check-out: the module's failure output stands).
# Requires jq.
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

# the path(s) an input names, one per line
input_paths() { jq -r --arg n "$1" '.inputs[$n] // empty | if type == "array" then .[] else . end | if type == "string" then . else tojson end' "$INV"; }
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

form_defects() { # <format> <file> <checks json>: the defects, as a JSON array
  local saved=$DEFECTS out
  DEFECTS='[]'
  case "$1" in
    markdown) check_markdown form "$2" "$3" ;;
    json) check_json form "$2" "$3" ;;
  esac
  out=$DEFECTS; DEFECTS=$saved
  printf '%s' "$out"
}

# --- check-in -----------------------------------------------------------------
check_in() {
  [ -e "$OUT/result.json" ] && die "the output directory already holds a result: $OUT (a run gets a new directory — 5.3)"
  mkdir -p "$OUT" || die "cannot create the output directory: $OUT"

  local v c
  v=$(jq -r '.contract // empty' "$INV")
  [ "$v" = "$(jq -r .contract <<<"$CONTRACT")" ] || defect "the invocation's contract version is '$v', the contract's $(jq -r .contract <<<"$CONTRACT")"

  # instructions: what the module does beyond its output directory (ADR-0040 D5)
  if jq -e 'has("instructions")' "$INV" >/dev/null; then
    jq -e '.instructions | type == "string" and test("\\S")' "$INV" >/dev/null || defect "instructions is not a non-empty string"
  fi

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
    # the forms this input may have: [{label, format, checks}] — another
    # module's output, or the form a file the invocation writes is given
    local prods
    prods=$(jq -c --argjson all "$all" --arg n "$n" '[[.inputs[$n].from] | flatten[]
              | select(type == "object" and (has("module") or (has("path") and has("checks"))))
              | if has("module") then
                  . as $f | ($all[$f.module].outputs[$f.output] // {}) as $o
                  | {label: "\($f.module) \($f.output)", format: ($o.format // ""), checks: ($o.checks // [])}
                else {label: "a file the invocation writes", format: (.format // ""), checks: .checks} end]' <<<"$CONTRACT")
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      if [ ! -e "$p" ]; then defect "input '$n': no such file: $p"; continue; fi
      jq -e 'length > 0' <<<"$prods" >/dev/null || continue
      [ -f "$p" ] || { defect "input '$n': not a file: $p"; continue; }
      local pr why="" d
      while IFS= read -r pr; do
        d=$(form_defects "$(jq -r .format <<<"$pr")" "$p" "$(jq -c .checks <<<"$pr")")
        if [ "$(jq length <<<"$d")" -eq 0 ]; then why=""; break; fi
        why="$why; as $(jq -r .label <<<"$pr"): $(jq -r 'map(sub("^form: "; "")) | join(", ")' <<<"$d")"
      done < <(jq -c '.[]' <<<"$prods")
      [ -z "$why" ] || defect "input '$n': $p is not of the form the contract asks${why}"
    done < <(input_paths "$n")
  done < <(jq -r '.inputs // {} | to_entries[] | [.key, (.value.required // false | tostring)] | join("\u001f")' <<<"$CONTRACT")

  finish check-in
  [ -f "$OUT/.check-in.json" ] || jq -n --arg m "$MODULE" '{module: $m}' >"$OUT/.check-in.json"
}

# --- check-out ----------------------------------------------------------------
OUTPUTS='{}'
record_output() { OUTPUTS=$(jq -c --arg n "$1" --argjson v "$2" '. + {($n): $v}' <<<"$OUTPUTS"); }

check_markdown() { # <output name> <file> <checks json>
  local n=$1 f=$2 checks=$3 model c t
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
        fi ;;
      *) defect "$n: the contract names a check this validator does not know: $t" ;;
    esac
  done < <(jq -c '.[]' <<<"$checks")
}

when_holds() { # <check json> <doc file>: does the check's "when", read in the file, hold?
  local c=$1 f=$2
  jq -e 'has("when") | not' <<<"$c" >/dev/null && return 0
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
      *) defect "$n: the contract names a check this validator does not know: $t" ;;
    esac
  done < <(jq -c '.[]' <<<"$checks")
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

  # a run that ended short of its expected output: its failure output stands
  # in place of the others, which are recorded where present (ADR-0039 D3)
  local ffile
  ffile=$(jq -r '[.outputs | to_entries[] | select(.value.failure // false) | .value.file][0] // empty' <<<"$CONTRACT")
  if [ -n "$ffile" ] && [ -f "$OUT/$ffile" ]; then
    grep -q '[^[:space:]]' "$OUT/$ffile" || defect "the failure output $ffile is empty"
    local on of om
    while IFS=$'\x1f' read -r on of om; do
      [ -n "$of" ] || continue
      if [ "$om" = true ]; then
        local fd; fd=$(cd "$OUT" 2>/dev/null && compgen -G "$of" | sort)
        [ -n "$fd" ] && record_output "$on" "$(printf '%s\n' "$fd" | jq -R --arg o "$OUT" 'select(. != "") | $o + "/" + .' | jq -sc .)"
      elif [ -f "$OUT/$of" ]; then
        record_output "$on" "$(jq -n --arg p "$OUT/$of" '$p')"
      fi
    done < <(jq -r '.outputs | to_entries[] | [.key, (.value.file // ""), (.value.many // false | tostring)] | join("\u001f")' <<<"$CONTRACT")
    finish check-out
    write_result failed
    printf 'failed: %s\n' "$OUT/$ffile" >&2
    exit 3
  fi

  local n fmt file req many
  while IFS=$'\x1f' read -r n fmt file req many; do
    local checks; checks=$(jq -c --arg n "$n" '.outputs[$n].checks // []' <<<"$CONTRACT")
    if [ "$many" = true ]; then
      local found; found=$(cd "$OUT" 2>/dev/null && compgen -G "$file" | sort)
      if [ -z "$found" ]; then [ "$req" = true ] && defect "$n: no file matches $file"; continue; fi
      record_output "$n" "$(printf '%s\n' "$found" | jq -R --arg o "$OUT" 'select(. != "") | $o + "/" + .' | jq -sc .)"
      continue
    fi
    if [ ! -f "$OUT/$file" ]; then [ "$req" = true ] && defect "$n: no $file"; continue; fi
    record_output "$n" "$(jq -n --arg p "$OUT/$file" '$p')"
    case "$fmt" in
      markdown) check_markdown "$n" "$OUT/$file" "$checks" ;;
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
  "json": ["keys", "forbidden_keys", "unique"]}'

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
    found=$(jq -r --argjson all "$all" --argjson known "$KNOWN_TYPES" '
      .inputs // {} | to_entries[] | .key as $k | ([.value.from] | flatten[])
      | . as $f
      | if type != "object" then "input \($k): from is not an object"
        elif has("module") then
          if ($all[$f.module] | not) then "input \($k): no contract for module \($f.module)"
          elif ($all[$f.module].outputs | has($f.output) | not) then "input \($k): module \($f.module) has no output \($f.output)"
          else empty end
        elif has("ledger") then empty
        elif has("path") then
          (if .path | IN("target", "invocation") | not then "input \($k): path is not target or invocation"
           elif has("checks") | not then empty
           elif ($known | has($f.format // "") | not) then "input \($k): the form of the file the invocation writes has a format the validator does not read"
           else ($f.checks[] | .type as $t | select(($known[$f.format] | index($t)) == null) | "input \($k): check type \(.type) is not one the validator implements for \($f.format)") end)
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
            (if any([$ch.when, ($ch.spec // {})[].required_when][] | objects; has("input")) or $ch.covers != null
             then "output \($o): a check reads the file alone, and this one names an input" else empty end)
        end,
        (if $v.failure then
           (if $v.format != "markdown" or (if $v | has("required") then $v.required else true end) != false or ($v.file // "") == "" then "output \($o): a failure output is a markdown file with required false" else empty end)
         else empty end)' <<<"$c") || say "outputs cannot be read"
    while IFS= read -r line; do [ -n "$line" ] && say "$line"; done <<<"$found"
    jq -e '[.outputs[] | select(.failure // false)] | length <= 1' <<<"$c" >/dev/null || say "more than one failure output"
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
