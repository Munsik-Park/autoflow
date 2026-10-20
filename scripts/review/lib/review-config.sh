#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
# =============================================================================
# Shared external-reviewer configuration resolver (issue #184; #979; #411; #463)
# =============================================================================
# SINGLE SOURCE OF TRUTH for reading the external-reviewer configuration — which
# external reviewers run beside the built-in Claude review, and each one's model
# and effort — and for mapping the resolved values onto each reviewer CLI's
# flags. Sourced (not executed) by:
#   - scripts/review/codex-review-pr.sh                (HANDOFF external review)
#   - scripts/preflight/check-review-backend.sh        (PREFLIGHT presence + --probe)
# so the live review and the on-demand probe cannot drift on source, parser,
# defaults or validation.
#
# Source order (issue #463) — the first file whose `.review` is present decides,
# and the list, the model and the effort all come from that one file:
#   1. local : the target's `.claude/autoflow.local.json`, at the root of the
#              repository the caller runs in (`git rev-parse --show-toplevel`;
#              the working directory outside a repository), whatever
#              subdirectory it runs from. REVIEW_CONFIG_PATH, when set, names
#              this file instead (a relative value is read from that root).
#   2. user  : the operator's `$HOME/.autoflow/config.json`
#              (scripts/lib/user-config.sh), read by the same parser.
#   3. none  : neither has `.review` — the built-in review runs alone.
# `.review` is present when it is not JSON `null`; `"reviewers": []` is present
# and names no external reviewer. A file without `.review` passes to the next
# step. The source is selected once per process, from the files as they are at
# that moment; every run reads them anew.
#
# Config shape (every key optional):
#
#   { "review": { "reviewers": ["codex"],
#                 "codex": { "model": "gpt-6-sol", "effort": "high" } } }
#
# External reviewers:
#   .review.reviewers  : an array of reviewer names — the external reviewers
#                        run beside the built-in review. `[]` = none.
#   .review.backend    : the earlier single-reviewer key, read only when
#                        `reviewers` is absent: "codex" reads as ["codex"];
#                        "claude" is rejected (the built-in review is Claude).
#   both absent        : none — the built-in review runs alone.
# Supported names: codex.
#
# Per reviewer, most specific first:
#   model  : .review.<name>.model > the reviewer's default (codex: gpt-6-sol)
#   effort : .review.<name>.effort > inherit
# "inherit" means NO flag is passed, so the CLI applies its own configuration.
# The codex model default is the operator's choice (issue #411): a file that
# pins nothing still reviews on that model.
#
# Unreadable conditions — a file that cannot be read as configured:
#   - the file is present but jq is not on PATH
#   - the file is present but not valid JSON
#   - .review is present but not an object
#   - .review.reviewers is present but not an array of non-empty strings, or
#     names an unsupported reviewer
#   - .review.backend (read when reviewers is absent) is present but not one
#     of codex | null
#   - .review.<name> is present but not an object
#   - .review.<name>.model / .effort is present but empty or not a string
#   - .review.<name>.effort is a string outside that reviewer's vocabulary
# An explicit JSON `null` reads as absent.
#
# The target file fails closed (exit 2, diagnostic on stderr naming the file,
# BEFORE any reviewer launches): it is opened when present, and each key is
# checked when it is read.
#
# The user file never fails closed. It is checked whole — every condition
# above, the list and every supported reviewer's model/effort — on every run,
# so both consumers reach the same verdict on the same file:
#   - user is the source (the target has no `.review`) and the file is
#     unreadable → REVIEW_SOURCE=user, REVIEW_USER_STATE=unreadable: nothing in
#     it applies, no external reviewer is resolved, and the consumer prints the fixed marker
#     line `user-config: UNREADABLE <path> — <error>` and exits
#     REVIEW_USER_UNREADABLE_EXIT (6) without launching a reviewer; the
#     orchestrator asks the operator whether to proceed without external review.
#   - the target decides and the user file is unreadable → REVIEW_USER_STATE=
#     warning: `user-config: WARNING <path> — <error>`; the result and the exit
#     code are the target's.
#
# Effort vocabularies (edit here — nowhere else — when a CLI's set evolves):
#   codex  : the named variants of `enum ReasoningEffort` in
#            codex-rs/protocol/src/openai_models.rs (codex-cli 0.153.4) —
#            none minimal low medium high xhigh max ultra persistent. codex
#            itself accepts any string as a Custom variant and does not reject
#            an unknown value at launch, so this list is the only guard.
#
# API (all in the caller's scope):
#   resolve_review_config <tag>
#       selects the source and sets REVIEW_SOURCE (local | user | none),
#       REVIEW_CFG_PATH (the deciding file, empty for none), REVIEW_USER_STATE
#       (absent | ok | warning | unreadable), REVIEW_USER_ERROR, and
#       REVIEW_REVIEWERS (space-separated names, empty = none — always so
#       when REVIEW_USER_STATE is unreadable); exits 2 on a
#       target-file condition. <tag> is the caller's stderr prefix (e.g.
#       codex-review, check-review-backend).
#   resolve_reviewer_settings <tag> <name>
#       selects the source when this process has not, and sets REVIEW_REVIEWER,
#       REVIEW_MODEL, REVIEW_EFFORT (empty = inherit) from the deciding file
#       (the defaults, read from no file, when REVIEW_USER_STATE is
#       unreadable); exits 2 on a target-file condition.
#   review_readout
#       prints the `source:` and `user-config:` readout lines (stdout).
#   build_review_backend_args
#       sets the REVIEW_BACKEND_ARGS array — the exact CLI flags for the
#       resolved reviewer, model and effort:
#         codex  : --model <m>  -c model_reasoning_effort=<e>
#   review_config_summary
#       prints `model=<m> effort=<e|inherit>` — for the start marker; never an
#       env dump.
# =============================================================================

REVIEW_CONFIG_DEFAULT_PATH=".claude/autoflow.local.json"
REVIEW_SUPPORTED_REVIEWERS="codex"
REVIEW_EFFORT_VOCAB_CODEX="none minimal low medium high xhigh max ultra persistent"
REVIEW_DEFAULT_MODEL_CODEX="gpt-6-sol"
REVIEW_USER_UNREADABLE_EXIT=6

# The user file's location (scripts/lib/user-config.sh), from this tree.
# shellcheck source=../../lib/user-config.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib" && pwd)/user-config.sh"

# Print the effort vocabulary for a reviewer (space-separated).
review_effort_vocab() {
  case "$1" in
    codex)  printf '%s' "$REVIEW_EFFORT_VOCAB_CODEX" ;;
    *)      printf '' ;;
  esac
}

# Print the default model for a reviewer.
review_default_model() {
  case "$1" in
    codex)  printf '%s' "$REVIEW_DEFAULT_MODEL_CODEX" ;;
    *)      printf '' ;;
  esac
}

_review_supported() {
  local n
  for n in $REVIEW_SUPPORTED_REVIEWERS; do
    [[ "$n" == "$1" ]] && return 0
  done
  return 1
}

# Read one optional string key `.review.<name>.<key>` into _REVIEW_OPT_VALUE
# (empty when the key is absent/null). Returns 1 (with a message on stderr via
# the caller's tag) when the key is present but empty or not a string. The
# value travels through a global rather than a command substitution so the
# failure return is observable under a caller's `set -e`.
_review_read_optional_string() {
  local tag="$1" cfg="$2" name="$3" key="$4" kind
  _REVIEW_OPT_VALUE=""
  kind="$(jq -r --arg b "$name" --arg k "$key" 'try (.review[$b][$k] | type) catch "unindexable"' "$cfg")"
  case "$kind" in
    null) return 0 ;;
    unindexable)
      echo "[${tag}] ${cfg} sets .review.${name} to a non-object, so .review.${name}.${key} cannot be read — refusing to launch the reviewer. Make it an object ({ \"model\": …, \"effort\": … }) or remove it." >&2
      return 1
      ;;
    string)
      _REVIEW_OPT_VALUE="$(jq -r --arg b "$name" --arg k "$key" '.review[$b][$k]' "$cfg")"
      if [[ -z "$_REVIEW_OPT_VALUE" ]]; then
        echo "[${tag}] ${cfg} sets an empty .review.${name}.${key} — refusing to launch the reviewer (an empty configured value must not be silently dropped). Set a value or remove the key." >&2
        return 1
      fi
      return 0
      ;;
    *)
      echo "[${tag}] ${cfg} sets .review.${name}.${key} to a ${kind}, expected a string — refusing to launch the reviewer. Set a string value or remove the key." >&2
      return 1
      ;;
  esac
}

# A present file requires jq and valid JSON; exits 2 otherwise.
_review_open_file() {
  local tag="$1" cfg="$2"
  if ! command -v jq >/dev/null 2>&1; then
    echo "[${tag}] ${cfg} is present but jq is not on PATH — refusing to guess the configured reviewers. Install jq or remove the file." >&2
    exit 2
  fi
  if ! jq -e . "$cfg" >/dev/null 2>&1; then
    echo "[${tag}] ${cfg} is present but not valid JSON — refusing to guess the configured reviewers. Fix or remove the file." >&2
    exit 2
  fi
}

# The target file: REVIEW_CONFIG_PATH, or the default, at the root of the
# repository the caller runs in — never relative to a subdirectory.
_review_target_path() {
  local root rel="${REVIEW_CONFIG_PATH:-$REVIEW_CONFIG_DEFAULT_PATH}"
  case "$rel" in
    /*) printf '%s' "$rel"; return 0 ;;
  esac
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || root=""
  [[ -n "$root" ]] || root="$(pwd -P)"
  printf '%s/%s' "$root" "$rel"
}

# Parse `.review`'s reviewer list from <cfg> into REVIEW_REVIEWERS; exits 2 on
# any unreadable condition. An absent (or null) `.review` is no reviewer.
_review_parse_list() {
  local tag="$1" cfg="$2" kind
  REVIEW_REVIEWERS=""
  kind="$(jq -r 'try (.review | type) catch "unindexable"' "$cfg")"
  case "$kind" in
    null) return 0 ;;
    object) ;;
    *)
      echo "[${tag}] ${cfg} sets .review to a ${kind}, expected an object — refusing to guess the configured reviewers. Make .review an object or remove it." >&2
      exit 2
      ;;
  esac

  kind="$(jq -r '.review.reviewers | type' "$cfg")"
  case "$kind" in
    array)
      if ! jq -e '.review.reviewers | all(type == "string" and length > 0)' "$cfg" >/dev/null; then
        echo "[${tag}] ${cfg} sets .review.reviewers to an array holding a non-string or empty entry — expected reviewer names (supported: ${REVIEW_SUPPORTED_REVIEWERS})." >&2
        exit 2
      fi
      REVIEW_REVIEWERS="$(jq -r '.review.reviewers | unique | join(" ")' "$cfg")"
      ;;
    null)
      # The earlier single-reviewer key.
      kind="$(jq -r '.review.backend | type' "$cfg")"
      case "$kind" in
        null) ;;
        string)
          local b
          b="$(jq -r '.review.backend' "$cfg")"
          case "$b" in
            codex) REVIEW_REVIEWERS="codex" ;;
            claude)
              echo "[${tag}] ${cfg} sets .review.backend to 'claude' — the claude reviewer backend was removed: the built-in Claude review runs on every pull request. Remove .review.backend, or set .review.reviewers to the external reviewers to run beside it (supported: ${REVIEW_SUPPORTED_REVIEWERS})." >&2
              exit 2
              ;;
            *)
              echo "[${tag}] ${cfg} sets .review.backend to '${b}' — expected 'codex'. Set .review.reviewers (supported: ${REVIEW_SUPPORTED_REVIEWERS}) or remove the key." >&2
              exit 2
              ;;
          esac
          ;;
        *)
          echo "[${tag}] ${cfg} sets .review.backend to a ${kind}, expected the string 'codex'. Set .review.reviewers (supported: ${REVIEW_SUPPORTED_REVIEWERS}) or remove the key." >&2
          exit 2
          ;;
      esac
      ;;
    *)
      echo "[${tag}] ${cfg} sets .review.reviewers to a ${kind}, expected an array of reviewer names (supported: ${REVIEW_SUPPORTED_REVIEWERS})." >&2
      exit 2
      ;;
  esac

  local n
  for n in $REVIEW_REVIEWERS; do
    if ! _review_supported "$n"; then
      echo "[${tag}] unknown external reviewer '${n}' in ${cfg} — supported: ${REVIEW_SUPPORTED_REVIEWERS}." >&2
      exit 2
    fi
  done
}

# Parse one reviewer's model/effort from <cfg> (empty <cfg> = no file) into
# REVIEW_MODEL / REVIEW_EFFORT; exits 2 on any unreadable condition.
_review_parse_settings() {
  local tag="$1" cfg="$2" name="$3"
  REVIEW_MODEL=""
  REVIEW_EFFORT=""
  if [[ -n "$cfg" ]]; then
    if ! _review_read_optional_string "$tag" "$cfg" "$name" model; then
      exit 2
    fi
    REVIEW_MODEL="$_REVIEW_OPT_VALUE"
    if ! _review_read_optional_string "$tag" "$cfg" "$name" effort; then
      exit 2
    fi
    REVIEW_EFFORT="$_REVIEW_OPT_VALUE"
  fi
  [[ -n "$REVIEW_MODEL" ]] || REVIEW_MODEL="$(review_default_model "$name")"

  if [[ -n "$REVIEW_EFFORT" ]]; then
    local vocab ok=0 e
    vocab="$(review_effort_vocab "$name")"
    for e in $vocab; do
      [[ "$e" == "$REVIEW_EFFORT" ]] && ok=1
    done
    if [[ "$ok" -ne 1 ]]; then
      echo "[${tag}] unsupported ${name} effort '${REVIEW_EFFORT}' in ${cfg} (.review.${name}.effort) — expected one of: ${vocab// /, }. Refusing to launch the reviewer; fix the value or remove the key to inherit." >&2
      exit 2
    fi
  fi
}

# The whole user-file check, run in a subshell so an unreadable condition is a
# verdict, not an exit: every condition, over the list and every supported
# reviewer's settings. Prints `review` when `.review` is present.
_review_check_user_file() {
  local tag="$1" cfg="$2" n
  _review_open_file "$tag" "$cfg"
  [[ "$(jq -r '.review | type' "$cfg")" == null ]] && return 0
  _review_parse_list "$tag" "$cfg"
  for n in $REVIEW_SUPPORTED_REVIEWERS; do
    _review_parse_settings "$tag" "$cfg" "$n"
  done
  printf 'review'
}

# Select the deciding file once per process (the source order above).
_review_select_source() {
  local tag="$1" target user kind out rc
  [[ "${_REVIEW_SOURCE_SELECTED:-0}" -eq 1 ]] && return 0
  REVIEW_SOURCE="none"
  REVIEW_CFG_PATH=""
  REVIEW_USER_STATE="absent"
  REVIEW_USER_ERROR=""
  target="$(_review_target_path)"
  user="$(autoflow_user_config_path)"
  REVIEW_USER_CFG_PATH="$user"

  # 1. The target file fails closed: opened when present.
  if [[ -f "$target" ]]; then
    _review_open_file "$tag" "$target"
    kind="$(jq -r 'try (.review | type) catch "unindexable"' "$target")"
    if [[ "$kind" != null ]]; then
      REVIEW_SOURCE="local"
      REVIEW_CFG_PATH="$target"
    fi
  fi

  # The user file is checked on every run: as the source, or for the warning.
  if [[ -n "$user" && -f "$user" ]]; then
    # (`&& … ||` keeps a caller's `set -e` from exiting on the verdict.)
    out="$(_review_check_user_file "$tag" "$user" 2>&1)" && rc=0 || rc=$?
    if [[ "$rc" -ne 0 ]]; then
      REVIEW_USER_ERROR="$(printf '%s' "$out" | sed "s/^\[${tag}\] //" | tr '\n' ' ' | sed 's/ *$//')"
      REVIEW_USER_ERROR="${REVIEW_USER_ERROR#"$user "}"
      if [[ "$REVIEW_SOURCE" == local ]]; then
        REVIEW_USER_STATE="warning"
      else
        # 2. The user file is the source; nothing in it applies.
        REVIEW_USER_STATE="unreadable"
        REVIEW_SOURCE="user"
        REVIEW_CFG_PATH="$user"
      fi
    else
      REVIEW_USER_STATE="ok"
      # 2. The user file decides when the target has no `.review`.
      if [[ "$REVIEW_SOURCE" == none && "$out" == review ]]; then
        REVIEW_SOURCE="user"
        REVIEW_CFG_PATH="$user"
      fi
    fi
  fi
  _REVIEW_SOURCE_SELECTED=1
}

resolve_review_config() {
  local tag="$1"
  REVIEW_REVIEWERS=""
  _review_select_source "$tag"
  [[ -n "$REVIEW_CFG_PATH" && "$REVIEW_USER_STATE" != unreadable ]] || return 0
  _review_parse_list "$tag" "$REVIEW_CFG_PATH"
}

resolve_reviewer_settings() {
  local tag="$1" name="$2"
  REVIEW_REVIEWER="$name"
  REVIEW_MODEL=""
  REVIEW_EFFORT=""
  if ! _review_supported "$name"; then
    echo "[${tag}] unknown external reviewer '${name}' — supported: ${REVIEW_SUPPORTED_REVIEWERS}." >&2
    exit 2
  fi
  _review_select_source "$tag"
  if [[ "$REVIEW_USER_STATE" == unreadable ]]; then
    _review_parse_settings "$tag" "" "$name"
  else
    _review_parse_settings "$tag" "$REVIEW_CFG_PATH" "$name"
  fi
}

# The readout lines both consumers print: where the configuration came from,
# and the user file's state. `user-config: UNREADABLE …` is the fixed marker
# of the "user file unreadable" result.
review_readout() {
  case "$REVIEW_SOURCE" in
    none) echo "source: none" ;;
    *)    echo "source: ${REVIEW_SOURCE} ${REVIEW_CFG_PATH}" ;;
  esac
  case "$REVIEW_USER_STATE" in
    absent)     echo "user-config: absent${REVIEW_USER_CFG_PATH:+ ${REVIEW_USER_CFG_PATH}}" ;;
    ok)         echo "user-config: ok ${REVIEW_USER_CFG_PATH}" ;;
    warning)    echo "user-config: WARNING ${REVIEW_USER_CFG_PATH} — ${REVIEW_USER_ERROR} (not applied; the target's .review decides)" ;;
    unreadable) echo "user-config: UNREADABLE ${REVIEW_USER_CFG_PATH} — ${REVIEW_USER_ERROR}" ;;
  esac
}

build_review_backend_args() {
  REVIEW_BACKEND_ARGS=()
  case "$REVIEW_REVIEWER" in
    codex)
      [[ -n "$REVIEW_MODEL" ]]  && REVIEW_BACKEND_ARGS+=(--model "$REVIEW_MODEL")
      [[ -n "$REVIEW_EFFORT" ]] && REVIEW_BACKEND_ARGS+=(-c "model_reasoning_effort=${REVIEW_EFFORT}")
      ;;
  esac
  return 0
}

review_config_summary() {
  printf 'model=%s effort=%s' "${REVIEW_MODEL:-inherit}" "${REVIEW_EFFORT:-inherit}"
}
