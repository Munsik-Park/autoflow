#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Munsik-Park
# SPDX-License-Identifier: Elastic-2.0
# scripts/handoff/confirm-ci-green.sh
#
# HANDOFF step 5 — deterministic "confirm CI is green" helper.
#
# Promotes the topology-independent step-5 invariant from prose
# (docs/autoflow-guide.md step 5) into a single enforceable invocation so the
# orchestrator never hand-writes a polling loop again (issue #25). It reads
# `mergeable`/`mergeStateStatus` FIRST and early-exits on CONFLICTING/DIRTY
# WITHOUT ever entering a poll (the PR #321 infinite-wait class); only when the
# PR is MERGEABLE/CLEAN does it run a finite, deadline-bounded poll that
# distinguishes "green" from "0 checks published" (webhook / scan-fallback
# suspect), "red build", and "still-pending at timeout" (slow CI) via layered
# exit codes — never reading a clean-but-empty status as green.
#
# Observe-only: it performs no merge, no CI re-trigger, and no conflict
# resolution. Conflict *resolution* stays topology-specific and lives in the
# docs (gitlink reconcile → docs/external-review-sequencing.md; other conflict
# → rebase origin/main). This script owns only the *confirmation*.
#
# Usage:
#   scripts/handoff/confirm-ci-green.sh --pr <N> [--repo <owner/name>]
#
# Options:
#   --pr <N>            Required. PR number to confirm. Non-numeric/missing -> exit 64.
#   --repo <owner/name> Optional. Forwarded to every `gh` call (cross-repo
#                       selector, mirrors scripts/review/codex-review-pr.sh).
#                       Omitted => the current repository (host PR).
#   -h | --help         Usage to stdout, exit 0.
#
# Tunables (env vars — the Approach-5 timeout / reconfirm policy as parameters):
#   CI_POLL_TIMEOUT_SECS   (default 900) Total finite poll budget (deadline).
#                          Generous so a normally-slow Jenkins build is not clipped.
#   CI_POLL_INTERVAL_SECS  (default 20)  Sleep between poll iterations.
#   Both validated as non-negative integers; non-numeric -> exit 64.
#
# Exit-code contract (feature §4):
#   0   CI green         — >=1 check present and every element green.
#   10  not mergeable    — CONFLICTING/DIRTY/!MERGEABLE at precheck OR on a
#                          mid-poll flip; stderr carries the reserved
#                          [HANDOFF-INTERNAL-RETRY] token. No poll on precheck.
#   11  0 checks         — MERGEABLE but no check ever published within the bound.
#   12  red build        — a check concluded FAILURE/ERROR/CANCELLED/TIMED_OUT.
#   13  still pending     — checks present but never all-green at the deadline (slow CI).
#   64  usage / bad arg / bad env int.
#
# `set -uo pipefail` (not -e): the poll intentionally tolerates a transient
# `gh` non-zero within the budget rather than crashing.
# =============================================================================

set -uo pipefail

usage() {
  echo "usage: $0 --pr <N> [--repo <owner/name>]" >&2
}

PR=""
REPO=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --pr) PR="${2:-}"; shift 2 ;;
    --repo) REPO="${2:-}"; shift 2 ;;
    -h|--help) echo "usage: $0 --pr <N> [--repo <owner/name>]"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage; exit 64 ;;
  esac
done

# --pr required and numeric.
case "$PR" in
  ''|*[!0-9]*) usage; exit 64 ;;
esac

# Env tunables: default when unset/empty, then validate as non-negative ints.
CI_POLL_TIMEOUT_SECS="${CI_POLL_TIMEOUT_SECS:-900}"
CI_POLL_INTERVAL_SECS="${CI_POLL_INTERVAL_SECS:-20}"
case "$CI_POLL_TIMEOUT_SECS" in ''|*[!0-9]*) echo "CI_POLL_TIMEOUT_SECS must be a non-negative integer" >&2; exit 64 ;; esac
case "$CI_POLL_INTERVAL_SECS" in ''|*[!0-9]*) echo "CI_POLL_INTERVAL_SECS must be a non-negative integer" >&2; exit 64 ;; esac
[ "$CI_POLL_INTERVAL_SECS" -lt 1 ] && CI_POLL_INTERVAL_SECS=1

# --repo forwarded to every gh call when provided.
REPO_ARGS=()
[ -n "$REPO" ] && REPO_ARGS=(--repo "$REPO")

# Bounded execution (feature D3 / DCR-5): prefer timeout/gtimeout, else a
# sleep+kill watchdog (holds on macOS with no GNU timeout — the incident box).
# Captures the command's stdout to $2 (a tempfile, NOT a $(...) subshell — a
# subshell would lose the RC/TIMED_OUT globals; ledger E14). Sets GH_RC and
# GH_TIMED_OUT (1 iff the watchdog fired). Used per in-loop `gh` round-trip so
# a hung call (stalled network / no-TTY auth prompt) is killed and control
# returns to the loop head for the deadline re-test.
gh_bounded() {
  local bound="$1" outfile="$2"; shift 2
  GH_TIMED_OUT=0
  local tbin=""
  if command -v timeout >/dev/null 2>&1; then
    tbin="timeout"
  elif command -v gtimeout >/dev/null 2>&1; then
    tbin="gtimeout"
  fi
  if [ -n "$tbin" ]; then
    "$tbin" "$bound" "$@" >"$outfile" 2>/dev/null
    GH_RC=$?
    [ "$GH_RC" -eq 124 ] && GH_TIMED_OUT=1
    return 0
  fi
  local marker; marker="$(mktemp)"
  "$@" >"$outfile" 2>/dev/null &
  local pid=$!
  ( sleep "$bound"; if kill -0 "$pid" 2>/dev/null; then kill "$pid" 2>/dev/null; echo fired >"$marker"; fi ) &
  local wpid=$!
  wait "$pid" 2>/dev/null
  GH_RC=$?
  if [ -s "$marker" ]; then
    GH_TIMED_OUT=1
  else
    kill "$wpid" 2>/dev/null
  fi
  wait "$wpid" 2>/dev/null
  rm -f "$marker" 2>/dev/null
  return 0
}

# Classify a poll body's statusCheckRollup into "<total> <fail> <green>".
classify_rollup() {
  jq -r '
    (.statusCheckRollup // []) as $r
    | ($r | length) as $t
    | ([ $r[] | select(
          (.__typename == "CheckRun" and (.conclusion | IN("FAILURE","ERROR","CANCELLED","TIMED_OUT")))
          or (.__typename == "StatusContext" and (.state | IN("FAILURE","ERROR")))
        )] | length) as $f
    | ([ $r[] | select(
          (.__typename == "CheckRun" and (.conclusion | IN("SUCCESS","NEUTRAL","SKIPPED")))
          or (.__typename == "StatusContext" and (.state == "SUCCESS"))
        )] | length) as $g
    | "\($t) \($f) \($g)"
  ' 2>/dev/null
}

# is_not_mergeable <mergeable> <mergeStateStatus> -> rc 0 iff not mergeable.
is_not_mergeable() {
  [ "$1" != "MERGEABLE" ] || [ "$2" = "CONFLICTING" ] || [ "$2" = "DIRTY" ]
}

# ---------------------------------------------------------------------------
# 1. PRECHECK (before any poll) — read mergeable/mergeStateStatus first.
# ---------------------------------------------------------------------------
pre_out="$(mktemp)"
gh pr view "$PR" "${REPO_ARGS[@]}" --json mergeable,mergeStateStatus >"$pre_out" 2>/dev/null
pre_body="$(cat "$pre_out")"; rm -f "$pre_out"

pre_mergeable="$(printf '%s' "$pre_body" | jq -r '.mergeable // empty' 2>/dev/null)"
pre_state="$(printf '%s' "$pre_body" | jq -r '.mergeStateStatus // empty' 2>/dev/null)"

if is_not_mergeable "$pre_mergeable" "$pre_state"; then
  echo "[HANDOFF-INTERNAL-RETRY] not mergeable (mergeStateStatus=${pre_state:-unknown}) — do NOT wait on CI; branch by cause (gitlink -> Reconcile preflight; other conflict -> rebase origin/main); HANDOFF internal retry" >&2
  exit 10
fi

# ---------------------------------------------------------------------------
# 2. POLL (only reached when MERGEABLE/CLEAN), deadline-bounded and finite.
# ---------------------------------------------------------------------------
deadline=$(( $(date +%s) + CI_POLL_TIMEOUT_SECS ))
saw_checks=0

while [ "$(date +%s)" -lt "$deadline" ]; do
  now="$(date +%s)"
  remaining=$(( deadline - now ))
  [ "$remaining" -le 0 ] && break

  # Per-call watchdog sub-bound: min(interval, remaining-to-deadline), >=1.
  sub_bound="$CI_POLL_INTERVAL_SECS"
  [ "$remaining" -lt "$sub_bound" ] && sub_bound="$remaining"
  [ "$sub_bound" -lt 1 ] && sub_bound=1

  poll_out="$(mktemp)"
  gh_bounded "$sub_bound" "$poll_out" \
    gh pr view "$PR" "${REPO_ARGS[@]}" --json mergeable,mergeStateStatus,statusCheckRollup
  body="$(cat "$poll_out")"; rm -f "$poll_out"

  # A hung call was killed, or a transient non-zero / empty read: tolerate,
  # re-test the deadline at the loop head, and continue within the budget.
  if [ "${GH_TIMED_OUT:-0}" -eq 1 ] || [ "${GH_RC:-0}" -ne 0 ] || [ -z "$body" ]; then
    now="$(date +%s)"; remaining=$(( deadline - now ))
    if [ "$remaining" -gt 0 ]; then
      sl="$CI_POLL_INTERVAL_SECS"; [ "$remaining" -lt "$sl" ] && sl="$remaining"
      sleep "$sl"
    fi
    continue
  fi

  # D5 — re-read mergeable every iteration; early-exit 10 on a mid-poll flip.
  m="$(printf '%s' "$body" | jq -r '.mergeable // empty' 2>/dev/null)"
  s="$(printf '%s' "$body" | jq -r '.mergeStateStatus // empty' 2>/dev/null)"
  if is_not_mergeable "$m" "$s"; then
    echo "[HANDOFF-INTERNAL-RETRY] not mergeable (mergeStateStatus=${s:-unknown}) — PR flipped mid-poll; do NOT wait on CI; branch by cause (gitlink -> Reconcile preflight; other conflict -> rebase origin/main); HANDOFF internal retry" >&2
    exit 10
  fi

  stats="$(printf '%s' "$body" | classify_rollup)"
  read -r total fail green <<<"${stats:-0 0 0}"
  total="${total:-0}"; fail="${fail:-0}"; green="${green:-0}"

  if [ "$fail" -gt 0 ]; then
    echo "a check concluded failure/error/cancelled/timed_out — red CI (route to RED)" >&2
    exit 12
  fi
  if [ "$total" -gt 0 ] && [ "$green" -eq "$total" ]; then
    exit 0
  fi
  if [ "$total" -gt 0 ]; then
    saw_checks=1
  fi

  # clamped-sleep: min(interval, remaining) so the loop cannot overshoot the
  # deadline by a full interval.
  now="$(date +%s)"; remaining=$(( deadline - now ))
  if [ "$remaining" -gt 0 ]; then
    sl="$CI_POLL_INTERVAL_SECS"; [ "$remaining" -lt "$sl" ] && sl="$remaining"
    sleep "$sl"
  fi
done

# ---------------------------------------------------------------------------
# 3. TIMEOUT — deadline reached without a terminal classification.
# ---------------------------------------------------------------------------
if [ "$saw_checks" -eq 0 ]; then
  echo "MERGEABLE but no check published within ${CI_POLL_TIMEOUT_SECS}s — suspect webhook / scan fallback (PeriodicFolderTrigger / synchronize re-push); NOT green" >&2
  exit 11
else
  echo "checks still pending after ${CI_POLL_TIMEOUT_SECS}s (slow CI) — inconclusive, re-run with a larger CI_POLL_TIMEOUT_SECS or escalate; NOT green" >&2
  exit 13
fi
