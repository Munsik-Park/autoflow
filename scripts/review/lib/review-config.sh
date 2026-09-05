#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# Shared reviewer configuration resolver (issue #184; extends issue #979)
# =============================================================================
# SINGLE SOURCE OF TRUTH for reading `.claude/autoflow.local.json`'s `review`
# section — backend, per-backend model, per-backend effort — and for mapping
# the resolved values onto each backend CLI's flags. Sourced (not executed) by:
#   - scripts/review/codex-review-pr.sh                (HANDOFF step-6 review)
#   - scripts/preflight/check-review-backend.sh        (PREFLIGHT presence + --probe)
# so the live review and the on-demand probe cannot drift on parser, defaults
# or validation (issue #184 Risk: "reading the same config independently in
# live review and probe can reintroduce drift").
#
# Config shape (target-owned scaffold, never overwritten; every key optional):
#
#   { "review": { "backend": "codex",
#                 "codex":  { "model": "gpt-5.6-sol", "effort": "high" },
#                 "claude": { "model": "opus",        "effort": "high" } } }
#
# Precedence, per value:
#   backend : --backend override (probe only) > .review.backend > codex
#   model   : .review.<backend>.model > MODEL env (claude backend only — the
#             pre-#184 passthrough, retained for compatibility) > inherit
#   effort  : .review.<backend>.effort > inherit
# "inherit" means NO flag is passed, so the CLI applies its own user/default
# configuration (~/.codex/config.toml for codex; the claude CLI's own defaults).
# Absence of a key is therefore never pinned to a default here — adding one
# would silently pin every existing install through the never-overwrite
# scaffold (issue #184 Risk).
#
# Fail-closed (exit 2, diagnostic on stderr, BEFORE any reviewer launches):
#   - the file is present but jq is not on PATH
#   - the file is present but not valid JSON
#   - .review.backend is present but empty, not a string (e.g. `false` — jq's
#     `//` would otherwise read it as the default), or not codex|claude
#   - .review or .review.<backend> is present but not an object
#   - .review.<backend>.model / .effort is present but empty or not a string
#   - .review.<backend>.effort is a string outside that backend's vocabulary
# An explicit JSON `null` reads as absent (inherit), matching #979's backend
# rule.
#
# Effort vocabularies (edit here — nowhere else — when a CLI's set evolves):
#   codex  : the named variants of `enum ReasoningEffort` in
#            codex-rs/protocol/src/openai_models.rs (codex-cli 0.153.4) —
#            none minimal low medium high xhigh max ultra persistent. codex
#            itself accepts any string as a Custom variant and does not reject
#            an unknown value at launch, so this list is the only guard.
#   claude : `claude --help` `--effort <level>` (low, medium, high, xhigh, max).
#
# API (all in the caller's scope):
#   resolve_review_config <tag> [<backend-override>]
#       sets REVIEW_BACKEND, REVIEW_MODEL, REVIEW_EFFORT (empty = inherit),
#       REVIEW_CFG_PATH; exits 2 on any fail-closed condition. <tag> is the
#       caller's stderr prefix (e.g. codex-review, check-review-backend).
#   build_review_backend_args
#       sets the REVIEW_BACKEND_ARGS array — the exact CLI flags for the
#       resolved backend, model and effort (empty array = inherit everything):
#         codex  : --model <m>  -c model_reasoning_effort=<e>
#         claude : --model <m>  --effort <e>
#   review_config_summary
#       prints `model=<m|inherit> effort=<e|inherit>` — the explicitly
#       configured values only, for the start marker; never an env dump.
# =============================================================================

REVIEW_CONFIG_DEFAULT_PATH=".claude/autoflow.local.json"
REVIEW_EFFORT_VOCAB_CODEX="none minimal low medium high xhigh max ultra persistent"
REVIEW_EFFORT_VOCAB_CLAUDE="low medium high xhigh max"

# Print the effort vocabulary for a backend (space-separated).
review_effort_vocab() {
  case "$1" in
    codex)  printf '%s' "$REVIEW_EFFORT_VOCAB_CODEX" ;;
    claude) printf '%s' "$REVIEW_EFFORT_VOCAB_CLAUDE" ;;
    *)      printf '' ;;
  esac
}

# Read one optional string key `.review.<backend>.<key>` into _REVIEW_OPT_VALUE
# (empty when the key is absent/null). Returns 1 (with a message on stderr via
# the caller's tag) when the key is present but empty or not a string. The
# value travels through a global rather than a command substitution so the
# failure return is observable under a caller's `set -e` (an assignment from a
# failing `$(…)` would abort with the helper's status instead of the resolver's
# exit 2).
_review_read_optional_string() {
  local tag="$1" cfg="$2" backend="$3" key="$4" kind
  _REVIEW_OPT_VALUE=""
  # `try … catch`: a non-object `.review.<backend>` section (e.g. a bare
  # string) is reported, not surfaced as a bare jq error with no diagnostic.
  kind="$(jq -r --arg b "$backend" --arg k "$key" 'try (.review[$b][$k] | type) catch "unindexable"' "$cfg")"
  case "$kind" in
    null) return 0 ;;
    unindexable)
      echo "[${tag}] ${cfg} sets .review.${backend} to a non-object, so .review.${backend}.${key} cannot be read — refusing to launch the reviewer. Make it an object ({ \"model\": …, \"effort\": … }) or remove it to inherit." >&2
      return 1
      ;;
    string)
      _REVIEW_OPT_VALUE="$(jq -r --arg b "$backend" --arg k "$key" '.review[$b][$k]' "$cfg")"
      if [[ -z "$_REVIEW_OPT_VALUE" ]]; then
        echo "[${tag}] ${cfg} sets an empty .review.${backend}.${key} — refusing to launch the reviewer (an empty configured value must not be silently dropped). Set a value or remove the key to inherit the ${backend} CLI's own default." >&2
        return 1
      fi
      return 0
      ;;
    *)
      echo "[${tag}] ${cfg} sets .review.${backend}.${key} to a ${kind}, expected a string — refusing to launch the reviewer. Set a string value or remove the key to inherit." >&2
      return 1
      ;;
  esac
}

resolve_review_config() {
  local tag="$1" override="${2:-}"
  REVIEW_CFG_PATH="${REVIEW_CONFIG_PATH:-$REVIEW_CONFIG_DEFAULT_PATH}"
  REVIEW_BACKEND=""
  REVIEW_MODEL=""
  REVIEW_EFFORT=""

  local have_cfg=0
  if [[ -f "$REVIEW_CFG_PATH" ]]; then
    have_cfg=1
    # A present file requires jq. Fail closed rather than silently downgrading
    # a configured backend/model/effort to the codex/inherit defaults
    # (issue #979 cycle 5b stance, now applied to every review key).
    if ! command -v jq >/dev/null 2>&1; then
      echo "[${tag}] ${REVIEW_CFG_PATH} is present but jq is not on PATH — refusing to fall back to codex (a configured backend must not be silently downgraded when its config cannot be read). Install jq or remove the file." >&2
      exit 2
    fi
    if ! jq -e . "$REVIEW_CFG_PATH" >/dev/null 2>&1; then
      echo "[${tag}] ${REVIEW_CFG_PATH} is present but not valid JSON — refusing to fall back to codex (a configured backend must not be silently downgraded). Fix or remove the file." >&2
      exit 2
    fi
  fi

  # Backend: explicit override (probe --backend) > configured > codex default.
  if [[ -n "$override" ]]; then
    REVIEW_BACKEND="$override"
  elif [[ "$have_cfg" -eq 1 ]]; then
    # Type-aware read (PR #188 review, Medium): jq's `a // b` also substitutes
    # for `false`, so `.review.backend // "codex"` would read an explicit
    # boolean `false` as the codex default — a silent downgrade. Only an
    # absent key or JSON `null` resolves to codex; any non-string value, an
    # empty string, or an unknown string is rejected. `try … catch` turns a
    # non-object `.review` into a diagnosable kind instead of a jq error.
    local kind
    kind="$(jq -r 'try (.review.backend | type) catch "unindexable"' "$REVIEW_CFG_PATH")"
    case "$kind" in
      null) REVIEW_BACKEND="codex" ;;
      string)
        REVIEW_BACKEND="$(jq -r '.review.backend' "$REVIEW_CFG_PATH")"
        if [[ -z "$REVIEW_BACKEND" ]]; then
          echo "[${tag}] ${REVIEW_CFG_PATH} sets an empty .review.backend — refusing to fall back to codex (an empty configured value must not be silently downgraded). Set a valid backend or remove the key." >&2
          exit 2
        fi
        ;;
      unindexable)
        echo "[${tag}] ${REVIEW_CFG_PATH} sets .review to a non-object, so .review.backend cannot be read — refusing to fall back to codex. Make .review an object or remove the file." >&2
        exit 2
        ;;
      *)
        echo "[${tag}] ${REVIEW_CFG_PATH} sets .review.backend to a ${kind}, expected the string 'codex' or 'claude' — refusing to fall back to codex (a non-string configured value must not be silently downgraded). Set a valid backend or remove the key." >&2
        exit 2
        ;;
    esac
  else
    REVIEW_BACKEND="codex"
  fi

  case "$REVIEW_BACKEND" in
    codex|claude) ;;
    *)
      echo "[${tag}] unknown review backend '${REVIEW_BACKEND}' — expected 'codex' or 'claude' (configured in ${REVIEW_CFG_PATH})." >&2
      exit 2
      ;;
  esac

  # Model / effort for the resolved backend (only when a config file exists).
  if [[ "$have_cfg" -eq 1 ]]; then
    if ! _review_read_optional_string "$tag" "$REVIEW_CFG_PATH" "$REVIEW_BACKEND" model; then
      exit 2
    fi
    REVIEW_MODEL="$_REVIEW_OPT_VALUE"
    if ! _review_read_optional_string "$tag" "$REVIEW_CFG_PATH" "$REVIEW_BACKEND" effort; then
      exit 2
    fi
    REVIEW_EFFORT="$_REVIEW_OPT_VALUE"
  fi

  # Legacy claude-only MODEL env passthrough (pre-#184 behavior, lowest
  # precedence). Applied here so the probe and the live review agree on it.
  if [[ -z "$REVIEW_MODEL" && "$REVIEW_BACKEND" == "claude" && -n "${MODEL:-}" ]]; then
    REVIEW_MODEL="$MODEL"
  fi

  # Effort vocabulary check (per backend).
  if [[ -n "$REVIEW_EFFORT" ]]; then
    local vocab ok=0 e
    vocab="$(review_effort_vocab "$REVIEW_BACKEND")"
    for e in $vocab; do
      [[ "$e" == "$REVIEW_EFFORT" ]] && ok=1
    done
    if [[ "$ok" -ne 1 ]]; then
      echo "[${tag}] unsupported ${REVIEW_BACKEND} effort '${REVIEW_EFFORT}' in ${REVIEW_CFG_PATH} (.review.${REVIEW_BACKEND}.effort) — expected one of: ${vocab// /, }. Refusing to launch the reviewer; fix the value or remove the key to inherit." >&2
      exit 2
    fi
  fi
}

build_review_backend_args() {
  REVIEW_BACKEND_ARGS=()
  case "$REVIEW_BACKEND" in
    codex)
      [[ -n "$REVIEW_MODEL" ]]  && REVIEW_BACKEND_ARGS+=(--model "$REVIEW_MODEL")
      [[ -n "$REVIEW_EFFORT" ]] && REVIEW_BACKEND_ARGS+=(-c "model_reasoning_effort=${REVIEW_EFFORT}")
      ;;
    claude)
      [[ -n "$REVIEW_MODEL" ]]  && REVIEW_BACKEND_ARGS+=(--model "$REVIEW_MODEL")
      [[ -n "$REVIEW_EFFORT" ]] && REVIEW_BACKEND_ARGS+=(--effort "$REVIEW_EFFORT")
      ;;
  esac
  return 0
}

review_config_summary() {
  printf 'model=%s effort=%s' "${REVIEW_MODEL:-inherit}" "${REVIEW_EFFORT:-inherit}"
}
