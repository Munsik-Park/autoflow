#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Spawn-policy readout — the one command every non-Workflow consumer calls
# =============================================================================
# The per-phase spawn policy (model + effort) lives in exactly one machine-
# readable place: .claude/autoflow/spawn-policy.json. Every non-Workflow
# consumer — the orchestrator before a direct spawn, the gate hook's advisory,
# the contract suites — obtains a value by running this script, never by
# reading a prose table. Editing one config row therefore changes the next
# spawn with no other file touched (CLAUDE.md > Spawn Model — Phase-by-Phase).
#
# Usage:
#   spawn-policy.sh model <phase-key>          -> the model literal
#   spawn-policy.sh effort <phase-key>         -> the effort, or `inherit`
#   spawn-policy.sh agent-effort <agent-type>  -> frontmatter effort, or
#                                                 `inherit` / `unmapped`
#   spawn-policy.sh models-for <agent-type>    -> every model any phase using
#                                                 that type declares, one per
#                                                 line; nothing at exit 0 for a
#                                                 type the policy models nowhere
#   spawn-policy.sh check                      -> validate; silent on success
#
# Exit: 0 resolved, 1 unknown key or failed validation (message on stderr),
#       2 usage.
#
# `inherit` is a PRINTED value, never an absence: empty stdout is reserved for
# the error paths, so (exit code, stdout) together separate an inheriting row
# from a quietly-failed resolver. `models-for` is the one exception — its
# answer is a set and the empty set is a legitimate answer, printed as nothing
# at exit 0, which is what the hook advisory's non-emptiness test reads.
# =============================================================================

set -uo pipefail

usage() {
  echo "usage: spawn-policy.sh {model|effort} <phase-key> | {agent-effort|models-for} <agent-type> | check" >&2
  exit 2
}

# ── Config resolution: script-relative, never cwd-relative ────────────────────
# The hook is the one caller whose working directory is not the repo root, so a
# bare `.` candidate would silently hand it "no policy". $AUTOFLOW_SPAWN_POLICY
# is the explicit override (the scratch-copy propagation leg), and it moves the
# agent-definition lookup below with it — one base, one tree.
_selfdir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG=""
for _cand in \
  "${AUTOFLOW_SPAWN_POLICY:-}" \
  "$_selfdir/../../.claude/autoflow/spawn-policy.json" \
  "${CLAUDE_PROJECT_DIR:-}/.claude/autoflow/spawn-policy.json"; do
  [ -n "$_cand" ] || continue
  if [ -f "$_cand" ]; then CONFIG="$_cand"; break; fi
done
if [ -z "$CONFIG" ]; then
  echo "spawn-policy: no spawn-policy.json found (set \$AUTOFLOW_SPAWN_POLICY to override)" >&2
  exit 1
fi
command -v jq >/dev/null 2>&1 || { echo "spawn-policy: jq is required" >&2; exit 1; }
jq -e . "$CONFIG" >/dev/null 2>&1 || { echo "spawn-policy: $CONFIG does not parse as JSON" >&2; exit 1; }

# The agent definitions are resolved from the SAME base the config resolved
# against — the directory that contained the config actually loaded — never
# independently and never from the caller's working directory. Two independent
# resolutions would let `check` validate one tree's config against another
# tree's definitions and report a partition that holds in neither.
_cfgdir="$(cd "$(dirname "$CONFIG")" && pwd)"          # <base>/.claude/autoflow
AGENTS_DIR="$(cd "$_cfgdir/.." && pwd)/agents"          # <base>/.claude/agents

# No admitted MODEL set lives here (issue #150, cycle 2). The config is a sample
# carrying the values currently applied, configured by the user at stamp/install
# time — not a universal vocabulary this script enforces — so a model value is
# checked for presence and shape only. The admitted EFFORT vocabulary is not
# hardcoded either: `check` reads it out of the config's own `effort_contract`,
# which makes `check` a self-consistency check over one source rather than a
# comparison against a second copy of the same vocabulary.

# Plugin-prefixed spellings (`<plugin>:autoflow-tester`) resolve to the bare
# type, matching what the hook's own role classifier already does — otherwise
# every plugin-channel spawn would resolve to the empty set and the advisory
# would read "no models admitted" for a type the policy fully governs.
normalize_type() {
  case "$1" in
    *:autoflow-*) printf '%s' "${1##*:}" ;;
    *)            printf '%s' "$1" ;;
  esac
}

cmd_model() {
  local key="$1" v
  v=$(jq -r --arg k "$key" '.phases[$k].model // empty' "$CONFIG")
  if [ -z "$v" ]; then
    echo "spawn-policy: no phases row '$key'" >&2
    exit 1
  fi
  printf '%s\n' "$v"
}

cmd_effort() {
  local key="$1" v
  v=$(jq -r --arg k "$key" '.phases[$k] | if . == null then empty else (.effort // empty) end' "$CONFIG")
  if [ -z "$v" ]; then
    echo "spawn-policy: no phases row '$key' (or the row declares no effort)" >&2
    exit 1
  fi
  printf '%s\n' "$v"
}

cmd_agent_effort() {
  local t v
  t=$(normalize_type "$1")
  if jq -e --arg t "$t" '.policy_unmapped_agent_types | has($t)' "$CONFIG" >/dev/null 2>&1; then
    printf 'unmapped\n'
    return 0
  fi
  v=$(jq -r --arg t "$t" '[.phases[] | select(.agent_type == $t) | .effort] | unique | .[]' "$CONFIG")
  if [ -z "$v" ]; then
    echo "spawn-policy: agent type '$t' is neither named by a phases row nor declared unmapped" >&2
    exit 1
  fi
  if [ "$(printf '%s\n' "$v" | wc -l | tr -d ' ')" != "1" ]; then
    echo "spawn-policy: agent type '$t' has divergent effort declarations across phases" >&2
    exit 1
  fi
  printf '%s\n' "$v"
}

cmd_models_for() {
  local t
  t=$(normalize_type "$1")
  # The empty set is a legitimate answer: nothing on stdout, exit 0.
  if jq -e --arg t "$t" '.policy_unmapped_agent_types | has($t)' "$CONFIG" >/dev/null 2>&1; then
    return 0
  fi
  jq -r --arg t "$t" '[.phases[] | select(.agent_type == $t) | .model] | unique | .[]' "$CONFIG"
  return 0
}

cmd_check() {
  local errs=0 v key line t
  local contract_ok=1 admitted_efforts="" inherit_sentinel="" integer_admitted=0
  _err() { echo "spawn-policy check: $1" >&2; errs=1; }

  # Model presence/shape. NOT vocabulary: a model value outside any previously
  # enumerated set is admitted. What remains is exactly what both workflow
  # scripts' site() already demands (a non-empty string `model`) and what their
  # row-totality check makes load-bearing — dropping it would leave `check`
  # green on a config both workflows refuse. A non-string model reaches the
  # loop as the empty string and is reported here.
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    key="${line%%=*}"; v="${line#*=}"
    [ -n "$v" ] || _err "phases.$key.model is absent, empty, or not a string"
  done < <(jq -r '.phases | to_entries[] | "\(.key)=\(if (.value.model|type) == "string" then .value.model else "" end)"' "$CONFIG")

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    key="${line%%=*}"; v="${line#*=}"
    [ -n "$v" ] || _err "workflow_sites.$key.model is absent, empty, or not a string"
  done < <(jq -r '.workflow_sites | to_entries[] | .key as $wf | .value | to_entries[] | "\($wf).\(.key)=\(if (.value.model|type) == "string" then .value.model else "" end)"' "$CONFIG")

  # `effort_contract` is validated BEFORE any row is examined, and its absence
  # fails closed. Reading a vocabulary out of the file being checked is only
  # safe when a missing or malformed contract is an error rather than an empty
  # admitted set — an empty set read silently would either reject every row or,
  # written the other way, admit every one. No row-level effort verdict is
  # produced from an unusable contract.
  if ! jq -e '(.effort_contract | type) == "object"' "$CONFIG" >/dev/null 2>&1; then
    _err "effort_contract is absent or not an object"
    contract_ok=0
  fi
  if [ "$contract_ok" = "1" ] \
     && ! jq -e '.effort_contract.admitted_values as $a | (($a|type) == "array") and ($a | all(type == "string"))' "$CONFIG" >/dev/null 2>&1; then
    _err "effort_contract.admitted_values is absent, not an array, or not an array of strings"
    contract_ok=0
  fi
  if [ "$contract_ok" = "1" ]; then
    # The published array mixes literal values with ONE type marker, `<integer>`.
    # The split is what the contract means: entries other than the marker form
    # the admitted string set, and the marker's presence is what enables the
    # JSON-integer branch below. A contract omitting the marker rejects integer
    # efforts.
    admitted_efforts="$(jq -r '[.effort_contract.admitted_values[] | select(. != "<integer>")] | join(" ")' "$CONFIG")"
    integer_admitted="$(jq -r 'if (.effort_contract.admitted_values | index("<integer>")) then 1 else 0 end' "$CONFIG")"
    inherit_sentinel="$(jq -r 'if (.effort_contract.config_inherit_sentinel | type) == "string" then .effort_contract.config_inherit_sentinel else "" end' "$CONFIG")"
    if [ -z "$admitted_efforts" ]; then
      _err "effort_contract.admitted_values carries no admitted value besides the <integer> marker"
      contract_ok=0
    fi
    if [ -z "$inherit_sentinel" ]; then
      _err "effort_contract.config_inherit_sentinel is absent, empty, or not a string"
      contract_ok=0
    fi
  fi

  # Effort admission — ONE admitted set for every row, no agent_type
  # conditional, read from the config's own `effort_contract` (so a runtime with
  # a different effort vocabulary is accommodated by editing the contract, never
  # by patching this checker). A row carrying no `effort` key at all fails here,
  # so a misspelled key surfaces as a validation error rather than reading as an
  # inherit.
  _check_effort() {   # <row-label> <json-type> <raw-value>
    local label="$1" jtype="$2" raw="$3"
    if [ "$jtype" = "absent" ]; then
      _err "$label carries no 'effort' key"
      return
    fi
    if [ "$jtype" = "number" ]; then
      if [ "$integer_admitted" != "1" ]; then
        _err "$label effort='$raw' is a JSON number, but effort_contract.admitted_values does not carry the <integer> marker"
        return
      fi
      case "$raw" in
        *.*) _err "$label effort='$raw' is not a JSON integer" ;;
      esac
      return
    fi
    if [ "$jtype" != "string" ]; then
      _err "$label effort='$raw' is neither a string nor an integer"
      return
    fi
    [ "$raw" = "$inherit_sentinel" ] && return
    case " $admitted_efforts " in
      *" $raw "*) ;;
      *) _err "$label effort='$raw' is not admitted by effort_contract.admitted_values ($inherit_sentinel | $admitted_efforts$([ "$integer_admitted" = "1" ] && printf ' | <integer>'))" ;;
    esac
  }

  while IFS=$'\t' read -r label jtype raw; do
    [ -n "$label" ] || continue
    [ "$contract_ok" = "1" ] || continue
    _check_effort "$label" "$jtype" "$raw"
  done < <(jq -r '.phases | to_entries[] | "phases.\(.key)\t\(if (.value|has("effort")) then (.value.effort|type) else "absent" end)\t\(.value.effort // "" | tostring)"' "$CONFIG")

  while IFS=$'\t' read -r label jtype raw; do
    [ -n "$label" ] || continue
    [ "$contract_ok" = "1" ] || continue
    _check_effort "$label" "$jtype" "$raw"
  done < <(jq -r '.workflow_sites | to_entries[] | .key as $wf | .value | to_entries[] | "workflow_sites.\($wf).\(.key)\t\(if (.value|has("effort")) then (.value.effort|type) else "absent" end)\t\(.value.effort // "" | tostring)"' "$CONFIG")

  # Agent-type membership: every phases[].agent_type is either a shipped
  # `.claude/agents/autoflow-*.md` basename or one of the three harness
  # research types, and nothing else.
  if [ ! -d "$AGENTS_DIR" ]; then
    # An absent definitions directory is NOT read as an empty set: the
    # partition rule below would then hold vacuously and `check` would report
    # success on a tree it never saw.
    echo "spawn-policy check: agent definitions directory not found at $AGENTS_DIR (resolved from $CONFIG)" >&2
    return 1
  fi
  # Every agent_type across .phases[], computed once and reused by the two
  # loops below (full-set membership, then the autoflow-* partition) instead
  # of re-querying the same static field from $CONFIG a third time further
  # down.
  local all_agent_types
  all_agent_types=$(jq -r '.phases[].agent_type' "$CONFIG" | sort -u)

  local defs
  defs=$(ls "$AGENTS_DIR" 2>/dev/null | sed -n 's/^\(autoflow-[^.]*\)\.md$/\1/p' | sort -u)
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    case "$t" in
      Explore|Plan|claude-code-guide) continue ;;
    esac
    printf '%s\n' "$defs" | grep -qxF "$t" || _err "phases[].agent_type='$t' names neither a shipped agent definition nor a harness research type"
  done < <(printf '%s\n' "$all_agent_types")

  # Partition (over the autoflow-* half only): the definition basenames equal
  # (autoflow-* phase types) ∪ (policy_unmapped_agent_types keys), disjoint.
  local phase_types unmapped union
  phase_types=$(printf '%s\n' "$all_agent_types" | grep '^autoflow-')
  unmapped=$(jq -r '.policy_unmapped_agent_types // {} | keys[]' "$CONFIG" | sort -u)
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    printf '%s\n' "$unmapped" | grep -qxF "$t" && _err "agent type '$t' is BOTH named by a phases row and declared unmapped"
  done < <(printf '%s\n' "$phase_types")
  union=$(printf '%s\n%s\n' "$phase_types" "$unmapped" | grep -v '^$' | sort -u)
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    printf '%s\n' "$union" | grep -qxF "$t" || _err "agent definition '$t' is neither named by a phases row nor declared unmapped"
  done < <(printf '%s\n' "$defs")
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    printf '%s\n' "$defs" | grep -qxF "$t" || _err "policy_unmapped_agent_types names '$t', which ships no agent definition"
  done < <(printf '%s\n' "$unmapped")

  # Deliberation turn ceilings (issue #152): the architect deliberation reads
  # its cold and bounded turn ceilings from `deliberation_caps` and fails
  # closed on a missing or malformed row, so `check` surfaces the defect in
  # the tree rather than at the next deliberation. Both values are integers
  # >= 2 — the turn-based termination condition pairs a turn with its
  # predecessor, so a ceiling below one full exchange could never converge.
  for capkey in max_turns bounded_max_turns; do
    if ! jq -e --arg k "$capkey" \
      '.deliberation_caps["architect-deliberation"][$k] | (type == "number") and (. == floor) and (. >= 2)' \
      "$CONFIG" >/dev/null 2>&1; then
      _err "deliberation_caps.architect-deliberation.$capkey is absent, not an integer, or < 2"
    fi
  done

  # Effort agreement: phases sharing an agent type declare the same effort.
  # Per-agent-type is the only granularity the direct-spawn channel has, so a
  # divergent declaration is undeliverable and fails here rather than silently.
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    if [ "$(jq -r --arg t "$t" '[.phases[] | select(.agent_type == $t) | .effort | tostring] | unique | length' "$CONFIG")" != "1" ]; then
      _err "phases sharing agent_type '$t' declare divergent effort values"
    fi
  done < <(printf '%s\n' "$all_agent_types")

  [ "$errs" = "0" ] || return 1
  return 0
}

[ $# -ge 1 ] || usage
case "$1" in
  model)        [ $# -eq 2 ] || usage; cmd_model "$2" ;;
  effort)       [ $# -eq 2 ] || usage; cmd_effort "$2" ;;
  agent-effort) [ $# -eq 2 ] || usage; cmd_agent_effort "$2" ;;
  models-for)   [ $# -eq 2 ] || usage; cmd_models_for "$2" ;;
  check)        [ $# -eq 1 ] || usage; cmd_check || exit 1 ;;
  *) usage ;;
esac
exit 0
