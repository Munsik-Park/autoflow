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

ADMITTED_MODELS="sonnet opus haiku"
ADMITTED_EFFORTS="low medium high xhigh max"

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
  _err() { echo "spawn-policy check: $1" >&2; errs=1; }

  # Model admission.
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    key="${line%%=*}"; v="${line#*=}"
    case " $ADMITTED_MODELS " in
      *" $v "*) ;;
      *) _err "phases.$key.model='$v' is not one of: $ADMITTED_MODELS" ;;
    esac
  done < <(jq -r '.phases | to_entries[] | "\(.key)=\(.value.model // "")"' "$CONFIG")

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    key="${line%%=*}"; v="${line#*=}"
    case " $ADMITTED_MODELS " in
      *" $v "*) ;;
      *) _err "workflow_sites.$key.model='$v' is not one of: $ADMITTED_MODELS" ;;
    esac
  done < <(jq -r '.workflow_sites | to_entries[] | .key as $wf | .value | to_entries[] | "\($wf).\(.key)=\(.value.model // "")"' "$CONFIG")

  # Effort admission — ONE admitted set for every row, no agent_type
  # conditional, `med` deliberately excluded (one spelling per level). A row
  # carrying no `effort` key at all fails here, so a misspelled key surfaces as
  # a validation error rather than reading as an inherit.
  _check_effort() {   # <row-label> <json-type> <raw-value>
    local label="$1" jtype="$2" raw="$3"
    if [ "$jtype" = "absent" ]; then
      _err "$label carries no 'effort' key"
      return
    fi
    if [ "$jtype" = "number" ]; then
      case "$raw" in
        *.*) _err "$label effort='$raw' is not a JSON integer" ;;
      esac
      return
    fi
    if [ "$jtype" != "string" ]; then
      _err "$label effort='$raw' is neither a string nor an integer"
      return
    fi
    [ "$raw" = "inherit" ] && return
    case " $ADMITTED_EFFORTS " in
      *" $raw "*) ;;
      *) _err "$label effort='$raw' is not admitted (inherit | $ADMITTED_EFFORTS | <integer>)" ;;
    esac
  }

  while IFS=$'\t' read -r label jtype raw; do
    [ -n "$label" ] || continue
    _check_effort "$label" "$jtype" "$raw"
  done < <(jq -r '.phases | to_entries[] | "phases.\(.key)\t\(if (.value|has("effort")) then (.value.effort|type) else "absent" end)\t\(.value.effort // "" | tostring)"' "$CONFIG")

  while IFS=$'\t' read -r label jtype raw; do
    [ -n "$label" ] || continue
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
