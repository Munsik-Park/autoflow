#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Shared external-reviewer configuration resolver (issue #184; #979; #411)
# =============================================================================
# SINGLE SOURCE OF TRUTH for reading `.claude/autoflow.local.json`'s `review`
# section — which external reviewers run beside the built-in Claude review, and
# each one's model and effort — and for mapping the resolved values onto each
# reviewer CLI's flags. Sourced (not executed) by:
#   - scripts/review/codex-review-pr.sh                (HANDOFF external review)
#   - scripts/preflight/check-review-backend.sh        (PREFLIGHT presence + --probe)
# so the live review and the on-demand probe cannot drift on parser, defaults
# or validation.
#
# Config shape (target-owned scaffold, never overwritten; every key optional):
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
# The codex model default is the operator's choice (issue #411): a target whose
# never-overwritten scaffold pins nothing still reviews on that model.
#
# Fail-closed (exit 2, diagnostic on stderr, BEFORE any reviewer launches):
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
# Effort vocabularies (edit here — nowhere else — when a CLI's set evolves):
#   codex  : the named variants of `enum ReasoningEffort` in
#            codex-rs/protocol/src/openai_models.rs (codex-cli 0.153.4) —
#            none minimal low medium high xhigh max ultra persistent. codex
#            itself accepts any string as a Custom variant and does not reject
#            an unknown value at launch, so this list is the only guard.
#
# API (all in the caller's scope):
#   resolve_review_config <tag>
#       sets REVIEW_REVIEWERS (space-separated names, empty = none) and
#       REVIEW_CFG_PATH; exits 2 on any fail-closed condition. <tag> is the
#       caller's stderr prefix (e.g. codex-review, check-review-backend).
#   resolve_reviewer_settings <tag> <name>
#       sets REVIEW_REVIEWER, REVIEW_MODEL, REVIEW_EFFORT (empty = inherit);
#       exits 2 on any fail-closed condition.
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

# A present file requires jq and valid JSON. Sets _REVIEW_HAVE_CFG.
_review_open_config() {
  local tag="$1"
  REVIEW_CFG_PATH="${REVIEW_CONFIG_PATH:-$REVIEW_CONFIG_DEFAULT_PATH}"
  _REVIEW_HAVE_CFG=0
  [[ -f "$REVIEW_CFG_PATH" ]] || return 0
  _REVIEW_HAVE_CFG=1
  if ! command -v jq >/dev/null 2>&1; then
    echo "[${tag}] ${REVIEW_CFG_PATH} is present but jq is not on PATH — refusing to guess the configured reviewers. Install jq or remove the file." >&2
    exit 2
  fi
  if ! jq -e . "$REVIEW_CFG_PATH" >/dev/null 2>&1; then
    echo "[${tag}] ${REVIEW_CFG_PATH} is present but not valid JSON — refusing to guess the configured reviewers. Fix or remove the file." >&2
    exit 2
  fi
}

resolve_review_config() {
  local tag="$1"
  REVIEW_REVIEWERS=""
  _review_open_config "$tag"
  [[ "$_REVIEW_HAVE_CFG" -eq 1 ]] || return 0

  local kind
  kind="$(jq -r 'try (.review | type) catch "unindexable"' "$REVIEW_CFG_PATH")"
  case "$kind" in
    null) return 0 ;;
    object) ;;
    *)
      echo "[${tag}] ${REVIEW_CFG_PATH} sets .review to a ${kind}, expected an object — refusing to guess the configured reviewers. Make .review an object or remove it." >&2
      exit 2
      ;;
  esac

  kind="$(jq -r '.review.reviewers | type' "$REVIEW_CFG_PATH")"
  case "$kind" in
    array)
      if ! jq -e '.review.reviewers | all(type == "string" and length > 0)' "$REVIEW_CFG_PATH" >/dev/null; then
        echo "[${tag}] ${REVIEW_CFG_PATH} sets .review.reviewers to an array holding a non-string or empty entry — expected reviewer names (supported: ${REVIEW_SUPPORTED_REVIEWERS})." >&2
        exit 2
      fi
      REVIEW_REVIEWERS="$(jq -r '.review.reviewers | unique | join(" ")' "$REVIEW_CFG_PATH")"
      ;;
    null)
      # The earlier single-reviewer key.
      kind="$(jq -r '.review.backend | type' "$REVIEW_CFG_PATH")"
      case "$kind" in
        null) ;;
        string)
          local b
          b="$(jq -r '.review.backend' "$REVIEW_CFG_PATH")"
          case "$b" in
            codex) REVIEW_REVIEWERS="codex" ;;
            claude)
              echo "[${tag}] ${REVIEW_CFG_PATH} sets .review.backend to 'claude' — the claude reviewer backend was removed: the built-in Claude review runs on every pull request. Remove .review.backend, or set .review.reviewers to the external reviewers to run beside it (supported: ${REVIEW_SUPPORTED_REVIEWERS})." >&2
              exit 2
              ;;
            *)
              echo "[${tag}] ${REVIEW_CFG_PATH} sets .review.backend to '${b}' — expected 'codex'. Set .review.reviewers (supported: ${REVIEW_SUPPORTED_REVIEWERS}) or remove the key." >&2
              exit 2
              ;;
          esac
          ;;
        *)
          echo "[${tag}] ${REVIEW_CFG_PATH} sets .review.backend to a ${kind}, expected the string 'codex'. Set .review.reviewers (supported: ${REVIEW_SUPPORTED_REVIEWERS}) or remove the key." >&2
          exit 2
          ;;
      esac
      ;;
    *)
      echo "[${tag}] ${REVIEW_CFG_PATH} sets .review.reviewers to a ${kind}, expected an array of reviewer names (supported: ${REVIEW_SUPPORTED_REVIEWERS})." >&2
      exit 2
      ;;
  esac

  local n
  for n in $REVIEW_REVIEWERS; do
    if ! _review_supported "$n"; then
      echo "[${tag}] unknown external reviewer '${n}' in ${REVIEW_CFG_PATH} — supported: ${REVIEW_SUPPORTED_REVIEWERS}." >&2
      exit 2
    fi
  done
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
  _review_open_config "$tag"
  if [[ "$_REVIEW_HAVE_CFG" -eq 1 ]]; then
    if ! _review_read_optional_string "$tag" "$REVIEW_CFG_PATH" "$name" model; then
      exit 2
    fi
    REVIEW_MODEL="$_REVIEW_OPT_VALUE"
    if ! _review_read_optional_string "$tag" "$REVIEW_CFG_PATH" "$name" effort; then
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
      echo "[${tag}] unsupported ${name} effort '${REVIEW_EFFORT}' in ${REVIEW_CFG_PATH} (.review.${name}.effort) — expected one of: ${vocab// /, }. Refusing to launch the reviewer; fix the value or remove the key to inherit." >&2
      exit 2
    fi
  fi
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
