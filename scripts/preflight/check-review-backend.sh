#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# =============================================================================
# PREFLIGHT external-reviewer availability report (issue #979, D5; #411)
# =============================================================================
# Reports whether each external reviewer named in .claude/autoflow.local.json
# (`.review.reviewers`, or the earlier `.review.backend`; none when both are
# absent) has its CLI on PATH. The built-in Claude review needs no CLI and is
# not checked here.
#
#   exit 0   → every configured external reviewer's CLI is present, or none is
#              configured.
#   exit 1   → a configured reviewer's CLI is absent; a reason on stderr names
#              it and the two remedies (install the CLI, or drop the reviewer
#              from .claude/autoflow.local.json). Advisory: HANDOFF runs the
#              built-in review alone and the aggregated comment records the
#              missing reviewer (docs/units/delivery.md > Reviewer review).
#   exit 2   → the review configuration cannot be read as configured.
#
# The per-cycle PREFLIGHT invocation (no `--probe`) is presence-only: a
# side-effect-free command whose exit encodes codex auth state does not exist,
# so auth is NOT a PREFLIGHT oracle. A present-but-unauthenticated reviewer
# passes here; its auth failure surfaces at the HANDOFF review run.
#
# `--probe` is a SEPARATE, on-demand mode: it makes one real authenticated
# round-trip against each configured external reviewer, over the same channel
# the HANDOFF review uses. It runs on-demand only — at install time (SKILL.md)
# and when the reviewer configuration changes — and is NEVER wired into
# PREFLIGHT and no hook consumes it. Its exit-code contract extends the
# presence 0/1/2: 0=authenticated (or none configured), 1=CLI absent
# (short-circuit, reuses the presence exit), 2=usage/config error,
# 3=indeterminate (timeout / no-TTY), 4=present-but-round-trip-failed.
#
# Model / effort: each reviewer's `.review.<name>.model` and `.effort` are
# resolved by the shared scripts/review/lib/review-config.sh — the same
# resolver the live wrapper uses — and the --probe round-trip passes them
# exactly as the HANDOFF review will.
#
# Usage: scripts/preflight/check-review-backend.sh [--probe]
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROBE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --probe)
      PROBE=1; shift ;;
    -h|--help)
      echo "Usage: $0 [--probe]"
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      echo "Usage: $0 [--probe]" >&2
      exit 2
      ;;
  esac
done

# Resolve the configured external reviewers through the SHARED resolver
# (scripts/review/lib/review-config.sh): a config the review would reject is
# rejected here with the same exit 2.
# shellcheck source=../review/lib/review-config.sh
. "$SCRIPT_DIR/../review/lib/review-config.sh"
resolve_review_config check-review-backend

# --------------------------------------------------------------------------
# --probe helpers (issue #979 cycle 9). Only reached when PROBE=1 AND the CLI
# is present (an absent CLI short-circuits to the existing presence exit 1
# below). Each dispatches a bounded, minimal, real round-trip; a success returns
# to the next reviewer, a failure exits with the probe contract
# (3 indeterminate / 4 round-trip-failed).
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

# Map a bounded run's outcome to the probe exit contract: return on success,
# exit otherwise.
probe_finish() {
  if [ "${PROBE_TIMED_OUT:-0}" -eq 1 ]; then
    echo "[check-review-backend] --probe: could not verify ${BACKEND} auth within ${1}s (timeout / no-TTY interactive-login) — indeterminate; it will surface at the HANDOFF reviewer review." >&2
    exit 3
  fi
  if [ "${PROBE_RC:-1}" -eq 0 ]; then
    return 0
  fi
  echo "[check-review-backend] --probe: ${BACKEND} is present but the authenticated round-trip failed (exit ${PROBE_RC}) — you will hit this at the HANDOFF reviewer review; fix credentials before your first cycle." >&2
  exit 4
}

# codex probe: a trivial-prompt `codex exec` with approval_policy="never" still opens codex's
# own model-API connection where auth happens (the dropped -s workspace-write /
# network_access flags govern the orthogonal command-execution sandbox).
probe_codex() {
  local bound="${PROBE_TIMEOUT_SECS:-20}"
  # REVIEW_BACKEND_ARGS (--model, and -c model_reasoning_effort=… when an
  # effort is configured) is the same array the live review passes.
  probe_run_bounded "$bound" \
    codex exec -c approval_policy="never" \
      ${REVIEW_BACKEND_ARGS[@]+"${REVIEW_BACKEND_ARGS[@]}"} \
      "Reply with the single token READY."
  probe_finish "$bound"
}

if [ -z "$REVIEW_REVIEWERS" ]; then
  echo "[check-review-backend] no external reviewer configured — the built-in Claude review runs alone."
  exit 0
fi

missing=0
for name in $REVIEW_REVIEWERS; do
  resolve_reviewer_settings check-review-backend "$name"
  build_review_backend_args
  BACKEND="$name"
  if ! command -v "$name" >/dev/null 2>&1; then
    echo "[check-review-backend] external reviewer '${name}' is unavailable: its CLI '${name}' is not on PATH." >&2
    echo "[check-review-backend] remedy 1 — install the ${name} CLI (see docs/reviewer-backend.md)." >&2
    echo "[check-review-backend] remedy 2 — drop '${name}' from .review.reviewers in .claude/autoflow.local.json." >&2
    echo "[check-review-backend] until then HANDOFF runs the built-in review without it, and the aggregated review comment records the omission." >&2
    missing=1
    continue
  fi
  if [ "$PROBE" -eq 1 ]; then
    # Probe marker: the reviewer and its effective model/effort, nothing else
    # from the environment — mirrors the live wrapper's start marker.
    echo "[check-review-backend] --probe: ${name} ($(review_config_summary))"
    case "$name" in
      codex) probe_codex ;;
    esac
  fi
done
exit "$missing"
