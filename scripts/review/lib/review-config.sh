#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Apache-2.0
# =============================================================================
# Shared reviewer configuration resolver (issue #184; #979; #411; #463; #485)
# =============================================================================
# SINGLE SOURCE OF TRUTH for reading the reviewer configuration — which
# reviewers run on a pull request, and each one's model, effort, rule file and
# lenses file — and for mapping the resolved values onto each reviewer CLI's
# flags. Sourced (not executed) by:
#   - scripts/review/claude-review-pr.sh               (REVIEW, claude)
#   - scripts/review/codex-review-pr.sh                (REVIEW, codex)
#   - scripts/preflight/check-review-backend.sh        (PREFLIGHT presence + --probe)
# so the live review and the on-demand probe cannot drift on source, parser,
# defaults or validation.
#
# Source (issue #485): the operator's `$HOME/.autoflow/config.json`
# (scripts/lib/user-config.sh) alone. A target's `.claude/autoflow.local.json`
# is not read for reviewers. The file is read anew on every run.
#
# Config shape (every key optional):
#
#   { "review": { "reviewers": ["claude", "codex"],
#                 "codex": { "model": "gpt-6-sol", "effort": "high",
#                            "rules": "<path>", "lenses": "<path>" } } }
#
# Reviewers:
#   .review.reviewers  : an array of reviewer names — the reviewers that run.
#                        Absent, null or `[]` names none of its own, and the
#                        default reviewers run.
# Supported names, and the default reviewers: claude codex.
#
# Per reviewer, most specific first:
#   model  : .review.<name>.model > the reviewer's default (claude: opus;
#            codex: gpt-6-sol)
#   effort : .review.<name>.effort > inherit
#   rules  : .review.<name>.rules > docs/review/review-<name>.md of this tree
#   lenses : .review.<name>.lenses > none
# "inherit" means NO flag is passed, so the CLI applies its own configuration.
# A relative rules or lenses path is read from the root of the repository the
# reviewer runs in (review_path).
#
# Unreadable conditions — a file that cannot be read as configured:
#   - the file is present but jq is not on PATH
#   - the file is present but not valid JSON
#   - .review is present but not an object
#   - .review.reviewers is present but not an array of non-empty strings, or
#     names an unsupported reviewer
#   - .review.<name> is present but not an object
#   - .review.<name>.model / .effort / .rules / .lenses is present but empty or
#     not a string
#   - .review.<name>.effort is a string outside that reviewer's vocabulary
# An explicit JSON `null` reads as absent.
#
# The file never fails closed. It is checked whole — every condition above,
# the list and every supported reviewer's settings — on every run, so every
# consumer reaches the same verdict on the same file. When it is unreadable,
# REVIEW_USER_STATE=unreadable: nothing in it applies, no reviewer is
# resolved, and the consumer prints the fixed marker line
# `user-config: UNREADABLE <path> — <error>` and exits
# REVIEW_USER_UNREADABLE_EXIT (6) without launching a reviewer; the
# review round goes on without those reviewers (docs/units/review.md).
#
# Effort vocabularies (edit here — nowhere else — when a CLI's set evolves):
#   claude : the values `claude --effort` accepts (Claude Code 2.1.304) —
#            low medium high xhigh max.
#   codex  : the named variants of `enum ReasoningEffort` in
#            codex-rs/protocol/src/openai_models.rs (codex-cli 0.153.4) —
#            none minimal low medium high xhigh max ultra persistent. codex
#            itself accepts any string as a Custom variant and does not reject
#            an unknown value at launch, so this list is the only guard.
#
# API (all in the caller's scope):
#   resolve_review_config <tag>
#       reads the file and sets REVIEW_SOURCE (user | none), REVIEW_CFG_PATH
#       (the file, empty for none), REVIEW_USER_STATE (absent | ok |
#       unreadable), REVIEW_USER_ERROR, and REVIEW_REVIEWERS (space-separated
#       names — empty when REVIEW_USER_STATE is unreadable). <tag> is the
#       caller's stderr prefix (e.g. codex-review, check-review-backend).
#   resolve_reviewer_settings <tag> <name>
#       reads the file when this process has not, and sets REVIEW_REVIEWER,
#       REVIEW_MODEL, REVIEW_EFFORT (empty = inherit), REVIEW_RULES and
#       REVIEW_LENSES (empty = none) from it (the defaults, read from no file,
#       when REVIEW_USER_STATE is unreadable); exits 2 on an unsupported name.
#   review_path <value> <root>
#       prints <value> when absolute, else <root>/<value>.
#   review_readout
#       prints the `source:` and `user-config:` readout lines (stdout).
#   build_review_backend_args
#       sets the REVIEW_BACKEND_ARGS array — the exact CLI flags for the
#       resolved reviewer, model and effort:
#         claude : --model <m>  --effort <e>
#         codex  : --model <m>  -c model_reasoning_effort=<e>
#   review_config_summary
#       prints `model=<m> effort=<e|inherit>` — for the start marker; never an
#       env dump.
# =============================================================================

REVIEW_SUPPORTED_REVIEWERS="claude codex"
REVIEW_DEFAULT_REVIEWERS="claude codex"
REVIEW_EFFORT_VOCAB_CLAUDE="low medium high xhigh max"
REVIEW_EFFORT_VOCAB_CODEX="none minimal low medium high xhigh max ultra persistent"
REVIEW_DEFAULT_MODEL_CLAUDE="opus"
REVIEW_DEFAULT_MODEL_CODEX="gpt-6-sol"
# The rule files of this tree: docs/review/review-<name>.md.
REVIEW_RULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/docs/review"
REVIEW_USER_UNREADABLE_EXIT=6

# The user file's location (scripts/lib/user-config.sh), from this tree.
# shellcheck source=../../lib/user-config.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../lib" && pwd)/user-config.sh"

# Print the effort vocabulary for a reviewer (space-separated).
review_effort_vocab() {
  case "$1" in
    claude) printf '%s' "$REVIEW_EFFORT_VOCAB_CLAUDE" ;;
    codex)  printf '%s' "$REVIEW_EFFORT_VOCAB_CODEX" ;;
    *)      printf '' ;;
  esac
}

# Print the default model for a reviewer.
review_default_model() {
  case "$1" in
    claude) printf '%s' "$REVIEW_DEFAULT_MODEL_CLAUDE" ;;
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

# Parse `.review`'s reviewer list from <cfg> into REVIEW_REVIEWERS; exits 2 on
# any unreadable condition. An absent (or null) `.review` names no reviewer.
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
    null) ;;
    *)
      echo "[${tag}] ${cfg} sets .review.reviewers to a ${kind}, expected an array of reviewer names (supported: ${REVIEW_SUPPORTED_REVIEWERS})." >&2
      exit 2
      ;;
  esac

  local n
  for n in $REVIEW_REVIEWERS; do
    if ! _review_supported "$n"; then
      echo "[${tag}] unknown reviewer '${n}' in ${cfg} — supported: ${REVIEW_SUPPORTED_REVIEWERS}." >&2
      exit 2
    fi
  done
}

# Parse one reviewer's model/effort/rules/lenses from <cfg> (empty <cfg> = no
# file) into REVIEW_MODEL / REVIEW_EFFORT / REVIEW_RULES / REVIEW_LENSES; exits 2
# on any unreadable condition.
_review_parse_settings() {
  local tag="$1" cfg="$2" name="$3"
  REVIEW_MODEL=""
  REVIEW_EFFORT=""
  REVIEW_RULES=""
  REVIEW_LENSES=""
  if [[ -n "$cfg" ]]; then
    _review_read_optional_string "$tag" "$cfg" "$name" model || exit 2
    REVIEW_MODEL="$_REVIEW_OPT_VALUE"
    _review_read_optional_string "$tag" "$cfg" "$name" effort || exit 2
    REVIEW_EFFORT="$_REVIEW_OPT_VALUE"
    _review_read_optional_string "$tag" "$cfg" "$name" rules || exit 2
    REVIEW_RULES="$_REVIEW_OPT_VALUE"
    _review_read_optional_string "$tag" "$cfg" "$name" lenses || exit 2
    REVIEW_LENSES="$_REVIEW_OPT_VALUE"
  fi
  [[ -n "$REVIEW_MODEL" ]] || REVIEW_MODEL="$(review_default_model "$name")"
  [[ -n "$REVIEW_RULES" ]] || REVIEW_RULES="${REVIEW_RULES_DIR}/review-${name}.md"

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

# Read the operator file once per process.
_review_select_source() {
  local tag="$1" user out rc
  [[ "${_REVIEW_SOURCE_SELECTED:-0}" -eq 1 ]] && return 0
  REVIEW_SOURCE="none"
  REVIEW_CFG_PATH=""
  REVIEW_USER_STATE="absent"
  REVIEW_USER_ERROR=""
  user="$(autoflow_user_config_path)"
  REVIEW_USER_CFG_PATH="$user"
  if [[ -n "$user" && -f "$user" ]]; then
    REVIEW_SOURCE="user"
    REVIEW_CFG_PATH="$user"
    # (`&& … ||` keeps a caller's `set -e` from exiting on the verdict.)
    out="$(_review_check_user_file "$tag" "$user" 2>&1)" && rc=0 || rc=$?
    if [[ "$rc" -ne 0 ]]; then
      REVIEW_USER_ERROR="$(printf '%s' "$out" | sed "s/^\[${tag}\] //" | tr '\n' ' ' | sed 's/ *$//')"
      REVIEW_USER_ERROR="${REVIEW_USER_ERROR#"$user "}"
      REVIEW_USER_STATE="unreadable"
    else
      REVIEW_USER_STATE="ok"
    fi
  fi
  _REVIEW_SOURCE_SELECTED=1
}

resolve_review_config() {
  local tag="$1"
  REVIEW_REVIEWERS=""
  _review_select_source "$tag"
  [[ "$REVIEW_USER_STATE" != unreadable ]] || return 0
  [[ -z "$REVIEW_CFG_PATH" ]] || _review_parse_list "$tag" "$REVIEW_CFG_PATH"
  [[ -n "$REVIEW_REVIEWERS" ]] || REVIEW_REVIEWERS="$REVIEW_DEFAULT_REVIEWERS"
}

resolve_reviewer_settings() {
  local tag="$1" name="$2"
  REVIEW_REVIEWER="$name"
  REVIEW_MODEL=""
  REVIEW_EFFORT=""
  if ! _review_supported "$name"; then
    echo "[${tag}] unknown reviewer '${name}' — supported: ${REVIEW_SUPPORTED_REVIEWERS}." >&2
    exit 2
  fi
  _review_select_source "$tag"
  if [[ "$REVIEW_USER_STATE" == unreadable ]]; then
    _review_parse_settings "$tag" "" "$name"
  else
    _review_parse_settings "$tag" "$REVIEW_CFG_PATH" "$name"
  fi
}

review_path() {
  case "$1" in
    /*) printf '%s' "$1" ;;
    *)  printf '%s/%s' "$2" "$1" ;;
  esac
}

# The readout lines every consumer prints: where the configuration came from,
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
    unreadable) echo "user-config: UNREADABLE ${REVIEW_USER_CFG_PATH} — ${REVIEW_USER_ERROR}" ;;
  esac
}

build_review_backend_args() {
  REVIEW_BACKEND_ARGS=()
  case "$REVIEW_REVIEWER" in
    claude)
      [[ -n "$REVIEW_MODEL" ]]  && REVIEW_BACKEND_ARGS+=(--model "$REVIEW_MODEL")
      [[ -n "$REVIEW_EFFORT" ]] && REVIEW_BACKEND_ARGS+=(--effort "$REVIEW_EFFORT")
      ;;
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
