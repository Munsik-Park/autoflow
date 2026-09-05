#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# PREFLIGHT reviewer-backend availability check (issue #979, D5)
# =============================================================================
# Fail-closed availability probe for the configured HANDOFF step-6 review
# backend. Resolves the backend (--backend override, else
# .claude/autoflow.local.json `.review.backend`, else codex) and confirms the
# backend's CLI is present on PATH.
#
#   exit 0   → the configured backend CLI is present (available).
#   exit ≠0  → the CLI is absent; a reason on stderr names the backend, that its
#              CLI is missing, and the two remedies (install the CLI, or switch
#              the backend in .claude/autoflow.local.json).
#
# The per-cycle PREFLIGHT invocation (no `--probe`) is presence-only, symmetric
# for both backends (C1): a side-effect-free command whose exit encodes
# claude/codex auth state does not exist, so auth is NOT a PREFLIGHT oracle. A
# present-but-unauthenticated backend passes this presence-only path; its auth
# failure surfaces at HANDOFF step 6 (the review run itself). See
# docs/reviewer-backend.md.
#
# `--probe` is a SEPARATE, on-demand mode (issue #979 cycle 9): it makes one real
# authenticated round-trip against the configured backend, over the identical
# auth channel + isolation HANDOFF step 6 uses. It runs on-demand only — at
# install time (SKILL.md) and at backend-change time — and is NEVER wired into
# PREFLIGHT and no hook consumes it (the presence-only path above is unchanged).
# Its exit-code contract extends the presence 0/1/2: 0=authenticated,
# 1=CLI absent (short-circuit, reuses the presence exit), 2=usage/config error,
# 3=indeterminate (timeout / no-TTY), 4=present-but-round-trip-failed. See §4.2
# of the feature design and docs/reviewer-backend.md.
#
# Wired into PREFLIGHT (presence-only path) as a drift-check-style stop
# condition: a non-zero exit stops the cycle before DIAGNOSE.
#
# Model / effort (issue #184): the backend's configured `.review.<backend>.model`
# and `.effort` are resolved by the shared scripts/review/lib/review-config.sh —
# the same resolver the live wrapper uses — and the --probe round-trip passes
# them exactly as HANDOFF step 6 will (or nothing, when inheriting).
#
# Usage: scripts/preflight/check-review-backend.sh [--backend codex|claude] [--probe]
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BACKEND_OVERRIDE=""
PROBE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --backend)
      [ $# -ge 2 ] || { echo "[check-review-backend] --backend requires a value (codex|claude)." >&2; exit 2; }
      BACKEND_OVERRIDE="$2"; shift 2 ;;
    --probe)
      PROBE=1; shift ;;
    -h|--help)
      echo "Usage: $0 [--backend codex|claude] [--probe]"
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      echo "Usage: $0 [--backend codex|claude] [--probe]" >&2
      exit 2
      ;;
  esac
done

# Resolve the effective backend + model/effort through the SHARED resolver
# (scripts/review/lib/review-config.sh, issue #184): explicit --backend override
# wins; else the target-owned scaffold; else the codex default. Model / effort
# come from `.review.<backend>` and default to inherit. The same parser,
# defaults and validation the live wrapper (codex-review-pr.sh) applies run
# here, so a config the review would reject is rejected at PREFLIGHT / probe
# time with the same exit 2 (jq absent, malformed JSON, empty/unknown backend,
# empty model/effort, effort outside the backend's vocabulary) — never a
# silent codex/inherit downgrade (issue #979 AC-2/AC-3, cycle 5b).
# shellcheck source=../review/lib/review-config.sh
. "$SCRIPT_DIR/../review/lib/review-config.sh"
resolve_review_config check-review-backend "$BACKEND_OVERRIDE"
BACKEND="$REVIEW_BACKEND"
build_review_backend_args

case "$BACKEND" in
  codex) CLI="codex" ;;
  claude) CLI="claude" ;;
esac

# --------------------------------------------------------------------------
# --probe helpers (issue #979 cycle 9). Only reached when PROBE=1 AND the CLI
# is present (an absent CLI short-circuits to the existing presence exit 1
# below). Each dispatches a bounded, minimal, real round-trip and exits with
# the §4.2 probe contract (0 ok / 3 indeterminate / 4 round-trip-failed).
# --------------------------------------------------------------------------

# Bounded execution (DCR-5): prefer timeout/gtimeout; else a sleep+kill
# watchdog. Reads PROBE_TIMEOUT_SECS via its caller. Sets PROBE_RC (the
# command's exit code) and PROBE_TIMED_OUT (1 iff the bound fired). This bound
# is net-new (codex-review-pr.sh carries no timeout) — a hanging no-TTY
# interactive-login prompt must not stall the operator's install.
probe_run_bounded() {
  local bound="$1"; shift
  PROBE_TIMED_OUT=0
  local tbin=""
  if command -v timeout >/dev/null 2>&1; then
    tbin="timeout"
  elif command -v gtimeout >/dev/null 2>&1; then
    tbin="gtimeout"
  fi
  if [ -n "$tbin" ]; then
    "$tbin" "$bound" "$@"
    PROBE_RC=$?
    [ "$PROBE_RC" -eq 124 ] && PROBE_TIMED_OUT=1
    return 0
  fi
  # No GNU timeout: run in the background and enforce the same bound with a
  # sleep+kill watchdog that leaves a marker iff it actually fired.
  local marker; marker="$(mktemp)"
  set -m
  "$@" </dev/null &
  local pid=$!
  ( sleep "$bound"
    if kill -0 "$pid" 2>/dev/null; then
      echo fired > "$marker"
      kill -TERM -"$pid" 2>/dev/null || kill "$pid" 2>/dev/null
    fi
  ) >/dev/null 2>&1 &
  local wpid=$!
  set +m
  wait "$pid" 2>/dev/null
  PROBE_RC=$?
  if [ -s "$marker" ]; then
    PROBE_TIMED_OUT=1
  else
    kill -TERM -"$wpid" 2>/dev/null || kill "$wpid" 2>/dev/null
  fi
  wait "$wpid" 2>/dev/null
  rm -f "$marker" 2>/dev/null
  return 0
}

# Map a bounded run's outcome to the probe exit contract and exit.
probe_finish() {
  if [ "${PROBE_TIMED_OUT:-0}" -eq 1 ]; then
    echo "[check-review-backend] --probe: could not verify ${BACKEND} auth within ${1}s (timeout / no-TTY interactive-login) — indeterminate; it will surface at HANDOFF step 6." >&2
    exit 3
  fi
  if [ "${PROBE_RC:-1}" -eq 0 ]; then
    exit 0
  fi
  echo "[check-review-backend] --probe: ${BACKEND} is present but the authenticated round-trip failed (exit ${PROBE_RC}) — you will hit this at HANDOFF step 6; fix credentials before your first cycle." >&2
  exit 4
}

# claude probe: mirror codex-review-pr.sh's step-6 isolation triple EXACTLY
# (shared helper), minimized to a review-content-free round-trip — a trivial
# prompt, zero tool grants, JSON output (confirms a model reply, not just a
# zero exit). The isolation fidelity is the crux: same auth channel/isolation
# as step 6, so a green probe predicts a green step 6.
probe_claude() {
  # shellcheck source=../review/lib/claude-isolation.sh
  . "$SCRIPT_DIR/../review/lib/claude-isolation.sh"
  local bound="${PROBE_TIMEOUT_SECS:-20}"
  if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    echo "[check-review-backend] --probe: ANTHROPIC_API_KEY is set; unsetting it for the claude probe subprocess to exercise the same subscription/OAuth channel HANDOFF step 6 uses." >&2
  fi
  build_claude_isolation
  local _orig; _orig="$(pwd)"
  cd "$NEUTRAL_CWD" 2>/dev/null || { cleanup_claude_isolation; PROBE_TIMED_OUT=1; probe_finish "$bound"; }
  # REVIEW_BACKEND_ARGS (--model / --effort, or nothing = inherit) is the same
  # array the live review passes, from the same resolver (issue #184).
  probe_run_bounded "$bound" \
    env "${CLAUDE_ISOLATION_UNSET[@]}" claude -p "Reply with the single token READY." \
      --setting-sources "" \
      --disallowedTools "Edit,Write,MultiEdit,Bash" \
      --output-format json \
      ${REVIEW_BACKEND_ARGS[@]+"${REVIEW_BACKEND_ARGS[@]}"}
  cd "$_orig" 2>/dev/null || cd /
  cleanup_claude_isolation
  probe_finish "$bound"
}

# codex probe: codex is a separate subprocess (no isolation triple needed) — a
# trivial-prompt `codex exec` with approval_policy="never" still opens codex's
# own model-API connection where auth happens (the dropped -s workspace-write /
# network_access flags govern the orthogonal command-execution sandbox).
probe_codex() {
  local bound="${PROBE_TIMEOUT_SECS:-20}"
  # REVIEW_BACKEND_ARGS (--model / -c model_reasoning_effort=…, or nothing =
  # inherit ~/.codex/config.toml) is the same array the live review passes
  # (issue #184).
  probe_run_bounded "$bound" \
    codex exec -c approval_policy="never" \
      ${REVIEW_BACKEND_ARGS[@]+"${REVIEW_BACKEND_ARGS[@]}"} \
      "Reply with the single token READY."
  probe_finish "$bound"
}

if command -v "$CLI" >/dev/null 2>&1; then
  if [ "$PROBE" -eq 1 ]; then
    # Probe marker: the backend and the effective explicitly configured
    # model/effort (`inherit` = the CLI's own default), nothing else from the
    # environment — mirrors the live wrapper's start marker (issue #184).
    echo "[check-review-backend] --probe: ${BACKEND} ($(review_config_summary))"
    case "$CLI" in
      claude) probe_claude ;;
      codex)  probe_codex  ;;
    esac
    # Unreachable: each probe_* function exits via probe_finish.
    exit 3
  fi
  exit 0
fi

echo "[check-review-backend] configured review backend '${BACKEND}' is unavailable: its CLI '${CLI}' is not on PATH." >&2
echo "[check-review-backend] remedy 1 — install the ${CLI} CLI (see docs/reviewer-backend.md)." >&2
echo "[check-review-backend] remedy 2 — switch the backend in .claude/autoflow.local.json (\`.review.backend\`)." >&2
exit 1
