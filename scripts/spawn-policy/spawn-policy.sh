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
# agent-definition lookup below with it — the base tree is the config's tree.
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

# The agent definitions are resolved from the tree the RUNTIME loads them from
# for the config actually loaded, never from the caller's working directory.
# Two locations exist (issue #169): the framework repository — and any target
# that carries its own copies — ships them at <base>/.claude/agents, while a
# thin-root target receives none of them (setup/manifest.json delivers the
# config and this readout only) and the harness loads them from the installed
# plugin's agents/ directory. `check` therefore reads <base>/.claude/agents
# when it holds at least one autoflow-*.md, and otherwise the plugin's agents/
# — resolved by scripts/lib/plugin-root.sh from $CLAUDE_PLUGIN_ROOT (hook
# context) or the harness's own registries under ${CLAUDE_CONFIG_DIR:-~/.claude}
# (a plain shell, where the operator runs `check`). The membership rule below
# stays a comparison of one tree's config against the definitions that tree's
# sessions spawn; what changed is only that the definitions' home is looked up
# rather than assumed adjacent (the gate hook already resolved this readout
# across the same two locations — hooks/check-autoflow-gate.sh § 1d).
_cfgdir="$(cd "$(dirname "$CONFIG")" && pwd)"          # <base>/.claude/autoflow
_base="$(cd "$_cfgdir/../.." && pwd)"                    # <base>
AGENTS_DIR=""
AGENTS_SOURCE=""
_local_agents="$_base/.claude/agents"
if [ -d "$_local_agents" ] && ls "$_local_agents"/autoflow-*.md >/dev/null 2>&1; then
  AGENTS_DIR="$_local_agents"; AGENTS_SOURCE="tree"
else
  # Helper lookup: beside this script, then the base tree, then the project
  # dir — the same three-way resolution the hook applies to this script.
  for _lib in \
    "$_selfdir/../lib/plugin-root.sh" \
    "$_base/scripts/lib/plugin-root.sh" \
    "${CLAUDE_PROJECT_DIR:-}/scripts/lib/plugin-root.sh"; do
    [ -n "$_lib" ] && [ -f "$_lib" ] || continue
    # shellcheck source=scripts/lib/plugin-root.sh
    . "$_lib"; break
  done
  _plugin_root=""
  if type autoflow_plugin_root >/dev/null 2>&1; then
    _plugin_root="$(autoflow_plugin_root "$_base" 2>/dev/null)" || _plugin_root=""
  elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    _plugin_root="$CLAUDE_PLUGIN_ROOT"
  fi
  if [ -n "$_plugin_root" ] && ls "$_plugin_root"/agents/autoflow-*.md >/dev/null 2>&1; then
    AGENTS_DIR="$_plugin_root/agents"; AGENTS_SOURCE="plugin"
  fi
fi

# Diagnostic for the fail-closed arm of `check`: every location consulted.
agents_dir_candidates() {
  if [ -d "$_local_agents" ]; then
    printf '%s (no autoflow-*.md)\n' "$_local_agents"
  else
    printf '%s (absent)\n' "$_local_agents"
  fi
  if type autoflow_plugin_root_candidates >/dev/null 2>&1; then
    autoflow_plugin_root_candidates "$_base" | sed 's|/*$|/agents|'
  else
    printf '$CLAUDE_PLUGIN_ROOT (%s)/agents [scripts/lib/plugin-root.sh not found — the registry and cache lookups were unavailable]\n' "${CLAUDE_PLUGIN_ROOT:-unset}"
  fi
}

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

# frontmatter_effort_line <definition.md>
#   Prints the `effort: <v>` line found inside the FIRST YAML frontmatter block
#   (line 1 is `---`, the block ends at the next `---`), or nothing when the
#   block carries no effort key. Exit 0 on either; 3 when the file has no such
#   block; 4 when the block carries the key more than once; 5 when an `effort:`
#   line sits outside the block. The harness reads the block only, so this is
#   the exact set of shapes the projection may accept (PR #183 review).
frontmatter_effort_line() {
  awk '
    NR == 1 { if ($0 != "---") exit 3; next }
    !closed && $0 == "---" { closed = 1; next }
    !closed && /^effort:/ { n++; line = $0; next }
    closed && /^effort:/ { outside++ }
    END {
      if (!closed) exit 3
      if (n > 1) exit 4
      if (outside > 0) exit 5
      if (n == 1) print line
      exit 0
    }' "$1"
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
  # `autoflow-*.md` definition basename (from the tree or the installed plugin
  # — see the AGENTS_DIR resolution above) or one of the three harness
  # research types, and nothing else.
  if [ -z "$AGENTS_DIR" ]; then
    # No definitions anywhere is NOT read as an empty set: the partition rule
    # below would then hold vacuously and `check` would report success on a
    # tree it never saw. Fail closed, naming every location consulted and the
    # override that points `check` at a plugin the lookup cannot see.
    {
      echo "spawn-policy check: no agent definitions (autoflow-*.md) found for $CONFIG"
      echo "  consulted, in order:"
      agents_dir_candidates | sed 's/^/    /'
      echo "  a thin-root target reads its definitions from the installed plugin; if the lookup above cannot see it, run: CLAUDE_PLUGIN_ROOT=<plugin dir> bash scripts/spawn-policy/spawn-policy.sh check"
    } >&2
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

  # Effort projection (issue #180, PR #183 review): a direct spawn's effort is
  # read by the harness from the agent definition's frontmatter, never from
  # this config — the Agent tool carries `model` per call but no effort. So a
  # phases[].effort is deliverable only when the LOADED definition carries the
  # same line (`effort: <v>`, or no line for the inherit sentinel). The
  # definitions are versioned tool source (a thin-root target loads the
  # plugin's), which makes phase-row effort fixed per plugin version and NOT a
  # per-target lever; only workflow_sites effort reaches its spawn from this
  # file at run time. Fail closed on a mismatch, so a config that claims an
  # effort the runtime will not apply cannot pass `check`.
  # The line is read from the FIRST YAML frontmatter block only (line 1 `---`
  # to the next `---`) — the harness reads nothing else. A duplicate key inside
  # the block, an `effort:` line outside it, or no block at all is an error in
  # its own right, never a silent "no line" (PR #183 review: a body-only line
  # passed a whole-file grep while the runtime inherited the session effort).
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    _exp=$(jq -r --arg t "$t" '[.phases[] | select(.agent_type == $t) | .effort | tostring] | unique | .[0]' "$CONFIG")
    case "$t" in
      Explore|Plan|claude-code-guide)
        # A harness research type ships no definition, so nothing carries an
        # effort line to the spawn: its rows admit the inherit sentinel only.
        [ "$_exp" = "$inherit_sentinel" ] || _err "phases rows for the harness research type '$t' declare effort '$_exp', but that type ships no agent definition, so a direct spawn of it inherits the session effort — only the inherit sentinel is deliverable there; a governed phase that needs a fixed effort uses a shipped definition (issue #180: diagnose-loopcheck moved to autoflow-loopcheck for this reason)"
        continue ;;
    esac
    [ -f "$AGENTS_DIR/$t.md" ] || continue   # absence is the membership error above, not a projection error
    _line=$(frontmatter_effort_line "$AGENTS_DIR/$t.md"); _frc=$?
    case "$_frc" in
      0) ;;
      3) _err "agent definition $AGENTS_DIR/$t.md has no YAML frontmatter block (line 1 must be '---', closed by a later '---'); the harness reads effort from that block only"; continue ;;
      4) _err "agent definition $AGENTS_DIR/$t.md carries more than one 'effort:' key inside its frontmatter block"; continue ;;
      5) _err "agent definition $AGENTS_DIR/$t.md carries an 'effort:' line outside its frontmatter block — the harness does not read it, so it is not a projection"; continue ;;
      *) _err "agent definition $AGENTS_DIR/$t.md: frontmatter read failed (rc $_frc)"; continue ;;
    esac
    if [ "$_exp" = "$inherit_sentinel" ]; then
      [ -z "$_line" ] || _err "phases rows for agent_type '$t' declare the inherit sentinel, but the loaded definition $AGENTS_DIR/$t.md carries '$_line' — a direct spawn's effort is fixed by the shipped definition's frontmatter (the channel the harness reads); set the rows to that value, since phase-row effort is not configurable per target (only workflow_sites effort is)"
    else
      [ "$_line" = "effort: $_exp" ] || _err "phases rows for agent_type '$t' declare effort '$_exp', but the loaded definition $AGENTS_DIR/$t.md carries '${_line:-no effort: line}' — a direct spawn's effort is fixed by the shipped definition's frontmatter (the channel the harness reads); set the rows to that value, since phase-row effort is not configurable per target (only workflow_sites effort is)"
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
